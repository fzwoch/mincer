/*
 * Mincer
 *
 * Copyright (C) 2013-2016 Florian Zwoch <fzwoch@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __GSTREAMER_H__
#define __GSTREAMER_H__

#include <gst/gst.h>

typedef enum {
	GST_VIDEO_ENCODER_X264 = 1,
	GST_VIDEO_ENCODER_HW
} video_encoder_t;

typedef enum {
	GST_AUDIO_ENCODER_AAC = 1,
	GST_AUDIO_ENCODER_MP3
} audio_encoder_t;

struct gstreamer_config {
	char *url;
	int video_device;
	int width;
	int height;
	int framerate;
	video_encoder_t video_encoder;
	audio_encoder_t audio_encoder;
	int video_speed;
	int video_bitrate;
	int audio_system_device;
	int audio_device;
	int audio_bitrate;
	char *recording;
};

class GStreamer
{
	GstElement *m_pipeline;
	
public:
	GStreamer();
	virtual ~GStreamer();
	
	void Start(const struct gstreamer_config &config);
	void Stop();
	
	void SetMute(bool mute);
	bool IsRunning();
};

#endif // __GSTREAMER_H__
