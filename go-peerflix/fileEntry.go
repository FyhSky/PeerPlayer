package main

import (
	"io"
	"os"

	"github.com/anacrolix/torrent"
)

// SeekableContent describes an io.ReadSeeker that can be closed as well.
type SeekableContent interface {
	io.ReadSeeker
	io.Closer
}

// FileEntry helps reading a torrent file.
type FileEntry struct {
	*torrent.File
	*torrent.Reader
	N int64 // max bytes remaining
}

// Emulating Seeker for each file entry.
func (f FileEntry) Seek(offset int64, whence int) (int64, error) {
	var off int64
	var err error
	if whence == os.SEEK_END {
		off, err = f.Reader.Seek(f.File.Offset()+f.File.Length()+offset, os.SEEK_SET)
	} else {
		off, err = f.Reader.Seek(f.File.Offset()+offset, whence)
	}
	return off - f.File.Offset(), err
}

// Copied from io.LimitReader
func (f *FileEntry) Read(p []byte) (n int, err error) {
	if f.N <= 0 {
		return 0, io.EOF
	}
	if int64(len(p)) > f.N {
		p = p[0:f.N]
	}
	n, err = f.Reader.Read(p)
	f.N -= int64(n)
	return
}

// NewFileReader sets up a torrent file for streaming reading.
func NewFileReader(f *torrent.File) (SeekableContent, error) {
	// Start download
	f.Download()

	torrent := f.Torrent()
	reader := torrent.NewReader()

	// Read ahead 10mb
	reader.SetReadahead(1024 * 1024 * 10)
	reader.SetResponsive()
	_, err := reader.Seek(f.Offset(), os.SEEK_SET)

	return &FileEntry{
		File:   f,
		Reader: reader,
		N:      f.Length(),
	}, err
}
