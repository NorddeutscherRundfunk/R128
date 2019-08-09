# R128
This application measures loudness according to EBU R128 with ffmpeg.

You can send video or audio files to the app.
Channel layout inside video can be mono or stereo. But mono files will temporarily merge to a stereo file at first.
If number of mono tracks is uneven it will return an error.
Temporary output.wav is exported to %temp% in 24bit 48kHz.