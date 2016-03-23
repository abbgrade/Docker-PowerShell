using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Tar
{
    public class TarWriter
    {
        private Stream _stream;
        private long _remaining;
        private int _remainingPadding;
        private byte[] _buffer = new byte[3 * TarUtils.BlockSize];
        private byte[] _paxBuffer = new byte[2 * TarUtils.BlockSize];
        private TarWriterStream _currentStream;

        public TarWriter(Stream stream)
        {
            _stream = stream;
            _currentStream = new TarWriterStream(this);
        }

/*
struct header_old_tar {
	char name[100];
	char mode[8];
	char uid[8];
	char gid[8];
	char size[12];
	char mtime[12];
	char checksum[8];
	char linkflag[1];
	char linkname[100];
	char pad[255];
};

struct header_posix_ustar {
	char name[100];
	char mode[8];
	char uid[8];
	char gid[8];
	char size[12];
	char mtime[12];
	char checksum[8];
	char typeflag[1];
	char linkname[100];
	char magic[6];
	char version[2];
	char uname[32];
	char gname[32];
	char devmajor[8];
	char devminor[8];
	char prefix[155];
	char pad[12];
};
        */

        public Stream CurrentFile
        {
            get { return _currentStream; }
        }

        private struct WriteState
        {
            public byte[] Buffer;
            public int Offset;
            public Dictionary<string, string> PaxEntries;
        }

        private static bool IsASCII(string s)
        {
            for (int i = 0; i < s.Length; i++)
            {
                if (s[i] > 127)
                {
                    return false;
                }
            }

            return true;
        }

        private static bool TryPutString(ref WriteState state, string str, int n, string paxKey)
        {
            if (str == null)
            {
                PutNul(ref state, n);
                return true;
            }

            if (IsASCII(str))
            {
                if (str.Length < n)
                {
                    for (int i = 0; i < str.Length; i++)
                    {
                        state.Buffer[state.Offset + i] = (byte)str[i];
                    }

                    state.Offset += str.Length;
                    PutNul(ref state, n - str.Length);
                    return true;
                }
            }

            if (paxKey != null)
            {
                state.PaxEntries[paxKey] = str;
            }

            return false;
        }

        private static bool TryPutOctal(ref WriteState state, long value, int n, string paxKey)
        {
            if (value >= 0)
            {
                var str = Convert.ToString(value, 8);
                if (TryPutString(ref state, str, n, null))
                {
                    return true;
                }
            }
            else
            {
                PutNul(ref state, n);
            }

            if (paxKey != null)
            {
                state.PaxEntries[paxKey] = value.ToString();
            }

            return false;
        }

        private static bool TryPutTime(ref WriteState state, DateTime time, int n, string paxKey)
        {
            uint nanoseconds;
            long unixTime = TarTime.ToUnixTime(time, out nanoseconds);
            if (TryPutOctal(ref state, unixTime, n, null) && nanoseconds == 0)
            {
                return true;
            }

            if (paxKey != null)
            {
                state.PaxEntries[paxKey] = ToPaxTime(time);
            }

            return false;
        }

        private static void PutNul(ref WriteState state, int n)
        {
            for (int i = 0; i < n; i++)
            {
                state.Buffer[state.Offset + i] = 0;
            }

            state.Offset += n;
        }

        public static string ToPaxTime(DateTime time)
        {
            uint nanoseconds;
            long seconds = TarTime.ToUnixTime(time, out nanoseconds);
            if (nanoseconds != 0)
            {
                return string.Format("{0}.{1:D7}", seconds, nanoseconds / 100);
            }
            else
            {
                return Convert.ToString(seconds);
            }
        }

        private static bool TrySplitPath(string path, out int splitIndex)
        {
            splitIndex = -1;
            if (!IsASCII(path))
            {
                return false;
            }

            for (int i = 0; i < path.Length; i++)
            {
                if (path[i] == '/')
                {
                    if (i < 155 && path.Length - i - 1 < 100)
                    {
                        splitIndex = i;
                        return true;
                    }
                }
            }

            return false;
        }

        public async Task AddEntryAsync(TarEntry entry)
        {
            ValidateWroteAll();

            var paxEntries = new Dictionary<string, string>();

            var state = new WriteState
            {
                Buffer = _buffer,
                PaxEntries = paxEntries
            };

            PutNul(ref state, _remainingPadding);
            var padding = _remainingPadding;
            _remainingPadding = 0;

            var nameState = state;
            var needsPath = false;
            if (!TryPutString(ref state, entry.Name, 100, null))
            {
                needsPath = true;
            }

            TryPutOctal(ref state, entry.Mode, 8, null);
            TryPutOctal(ref state, entry.UserID, 8, TarUtils.PaxUid);
            TryPutOctal(ref state, entry.GroupID, 8, TarUtils.PaxGid);
            TryPutOctal(ref state, entry.Length, 12, TarUtils.PaxSize);
            TryPutTime(ref state, entry.ModifiedTime, 12, TarUtils.PaxMtime);

            // Remember the offset for the checksum to fill it in later.
            var checksumState = state;
            PutNul(ref state, 7);
            // The 8th byte of the checksum is always ' '.
            state.Buffer[state.Offset] = (byte)' ';
            state.Offset++;

            state.Buffer[state.Offset] = (byte)entry.Type;
            state.Offset++;

            TryPutString(ref state, entry.LinkTarget, 100, TarUtils.PaxLinkpath);
            TryPutString(ref state, TarUtils.PosixMagic, 6, null);

            state.Buffer[state.Offset] = (byte)'0';
            state.Buffer[state.Offset + 1] = (byte)'0';
            state.Offset += 2;

            TryPutString(ref state, entry.UserName, 32, TarUtils.PaxUname);
            TryPutString(ref state, entry.GroupName, 32, TarUtils.PaxGname);
            TryPutOctal(ref state, entry.DeviceMajor, 8, TarUtils.PaxDevmajor);
            TryPutOctal(ref state, entry.DeviceMinor, 8, TarUtils.PaxDevminor);

            // Remember the offset for the prefix in case we need it later.
            var prefixState = state;

            PutNul(ref state, padding + TarUtils.BlockSize - state.Offset);

            if (entry.AccessTime.HasValue)
            {
                paxEntries[TarUtils.PaxAtime] = ToPaxTime(entry.AccessTime.Value);
            }

            if (entry.ChangeTime.HasValue)
            {
                paxEntries[TarUtils.PaxCtime] = ToPaxTime(entry.ChangeTime.Value);
            }

            if (needsPath)
            {
                int splitIndex;
                if (paxEntries.Count == 0 && TrySplitPath(entry.Name, out splitIndex))
                {
                    TryPutString(ref prefixState, entry.Name.Substring(0, splitIndex), 155, null);
                    TryPutString(ref nameState, entry.Name.Substring(splitIndex + 1), 100, null);
                }
                else
                {
                    paxEntries[TarUtils.PaxPath] = entry.Name;
                }
            }

            int signedChecksum;
            var checksum = TarUtils.Checksum(_buffer, padding, out signedChecksum);
            TryPutOctal(ref checksumState, checksum, 7, null);

            if (paxEntries.Count > 0)
            {
                // TODO
                throw new NotSupportedException();
            }

            await _stream.WriteAsync(_buffer, 0, state.Offset);
            _remaining = entry.Length;
            _remainingPadding = TarUtils.BlockSize - (int)(entry.Length % TarUtils.BlockSize);
            if (_remainingPadding == TarUtils.BlockSize)
            {
                _remainingPadding = 0;
            }
        }

        private void ZeroArray(byte[] buffer, int offset, int length)
        {
            for (int i = 0; i < length; i++)
            {
                buffer[offset + i] = 0;
            }
        }

        public async Task CloseAsync()
        {
            ValidateWroteAll();
            ZeroArray(_buffer, 0, _buffer.Length);
            await _stream.WriteAsync(_buffer, 0, _remainingPadding + TarUtils.BlockSize * 2);
        }

        private void ValidateWroteAll()
        {
            if (_remaining > 0)
            {
                throw new Exception(string.Format("did not finish writing last entry: {0}", _remaining));
            }
        }

        internal void WriteCurrentFile(byte[] buffer, int offset, int count)
        {
            if (count > _remaining)
            {
                throw new Exception("wrote too much");
            }

            _stream.Write(buffer, offset, count);
            _remaining -= count;
        }

        internal async Task WriteCurrentFileAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken)
        {
            if (count > _remaining)
            {
                throw new Exception("wrote too much");
            }

            await _stream.WriteAsync(buffer, offset, count, cancellationToken);
            _remaining -= count;
        }
    }
}