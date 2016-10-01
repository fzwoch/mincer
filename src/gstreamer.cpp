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

#include "gstreamer.h"
#include "app.h"

static GstBusSyncReply bus_callback(GstBus *bus, GstMessage *msg, gpointer data)
{
	GError *err;
	
	switch (GST_MESSAGE_TYPE(msg))
	{
		case GST_MESSAGE_WARNING:
			gst_message_parse_warning(msg, &err, NULL);
			wxLogVerbose("%s", err->message);
			g_error_free(err);
			break;
		case GST_MESSAGE_ERROR:
			gst_bus_set_sync_handler(bus, NULL, NULL, NULL);
			gst_message_parse_error(msg, &err, NULL);
			wxGetApp().CallAfter(&myApp::GStreamerError, err->message);
			g_error_free(err);
			break;
		default:
			break;
	}
	
	return GST_BUS_DROP;
}

extern "C" {
#if defined __APPLE__ || defined _WIN32
	GST_PLUGIN_STATIC_DECLARE(audioconvert);
	GST_PLUGIN_STATIC_DECLARE(audiomixer);
	GST_PLUGIN_STATIC_DECLARE(audioparsers);
	GST_PLUGIN_STATIC_DECLARE(audioresample);
	GST_PLUGIN_STATIC_DECLARE(audiotestsrc);
	GST_PLUGIN_STATIC_DECLARE(coreelements);
	GST_PLUGIN_STATIC_DECLARE(flv);
	GST_PLUGIN_STATIC_DECLARE(isomp4);
	GST_PLUGIN_STATIC_DECLARE(lame);
	GST_PLUGIN_STATIC_DECLARE(rtmp);
	GST_PLUGIN_STATIC_DECLARE(videoconvert);
	GST_PLUGIN_STATIC_DECLARE(videoparsersbad);
	GST_PLUGIN_STATIC_DECLARE(videoscale);
	GST_PLUGIN_STATIC_DECLARE(voaacenc);
	GST_PLUGIN_STATIC_DECLARE(volume);
	GST_PLUGIN_STATIC_DECLARE(x264);
#endif
	
#if defined __APPLE__
	GST_PLUGIN_STATIC_DECLARE(applemedia);
	GST_PLUGIN_STATIC_DECLARE(osxaudio);
#elif defined _WIN32
	GST_PLUGIN_STATIC_DECLARE(directsoundsrc);
	GST_PLUGIN_STATIC_DECLARE(winscreencap);
#endif
}

GStreamer::GStreamer()
	: m_pipeline(NULL)
{
#if defined __APPLE__ || defined _WIN32
	extern gboolean _priv_gst_disable_registry_update;
	
	_priv_gst_disable_registry_update = TRUE;
#endif
	
	gst_init(NULL, NULL);
	
#if defined __APPLE__ || defined _WIN32
	GST_PLUGIN_STATIC_REGISTER(audioconvert);
	GST_PLUGIN_STATIC_REGISTER(audiomixer);
	GST_PLUGIN_STATIC_REGISTER(audioparsers);
	GST_PLUGIN_STATIC_REGISTER(audioresample);
	GST_PLUGIN_STATIC_REGISTER(audiotestsrc);
	GST_PLUGIN_STATIC_REGISTER(coreelements);
	GST_PLUGIN_STATIC_REGISTER(flv);
	GST_PLUGIN_STATIC_REGISTER(isomp4);
	GST_PLUGIN_STATIC_REGISTER(lame);
	GST_PLUGIN_STATIC_REGISTER(rtmp);
	GST_PLUGIN_STATIC_REGISTER(videoconvert);
	GST_PLUGIN_STATIC_REGISTER(videoparsersbad);
	GST_PLUGIN_STATIC_REGISTER(videoscale);
	GST_PLUGIN_STATIC_REGISTER(voaacenc);
	GST_PLUGIN_STATIC_REGISTER(volume);
	GST_PLUGIN_STATIC_REGISTER(x264);
#endif
	
#if defined __APPLE__
	GST_PLUGIN_STATIC_REGISTER(applemedia);
	GST_PLUGIN_STATIC_REGISTER(osxaudio);
#elif defined _WIN32
	GST_PLUGIN_STATIC_REGISTER(directsoundsrc);
	GST_PLUGIN_STATIC_REGISTER(winscreencap);
#endif
}

GStreamer::~GStreamer()
{
	Stop();
}

void GStreamer::Start(myFrame *frame)
{
	GError *err = NULL;
	GString *desc = g_string_new(NULL);
	GDateTime *date = g_date_time_new_now_local();
	GstBus *bus = NULL;
	
	if (m_pipeline != NULL)
	{
		Stop();
	}
	
#if defined __APPLE__
	if (frame->GetVideoDevice() < frame->GetScreenCount())
	{
		g_string_append_printf(desc, "avfvideosrc name=video_src do-stats=true device-index=%d capture-screen=true capture-screen-cursor=true ! ", frame->GetVideoDevice());
	}
	else
	{
		g_string_append_printf(desc, "avfvideosrc name=video_src do-stats=true device-index=%d ! ", frame->GetVideoDevice() - frame->GetScreenCount());
	}
#elif defined _WIN32
	g_string_append_printf(desc, "dx9screencapsrc monitor=%d ! ", frame->GetVideoDevice());
#else
	g_string_append_printf(desc, "ximagesrc use-damage=false show-pointer=true display-name=:0.%d ! ", frame->GetVideoDevice());
#endif
	
	if (frame->GetVideoDevice() < frame->GetScreenCount())
	{
		g_string_append_printf(desc, "video/x-raw, framerate=%d/1 ! ", frame->GetFramerate());
	}

	g_string_append_printf(desc, "queue max-size-bytes=0 max-size-buffers=0 max-size-time=4000000000 ! ");
	g_string_append_printf(desc, "videoconvert ! queue max-size-bytes=0 ! ");
	g_string_append_printf(desc, "videoscale method=lanczos ! queue max-size-bytes=0 ! video/x-raw, width=%d, height=%d ! ", frame->GetWidth(), frame->GetHeight());
	
	if (frame->GetVideoEncoder() == 0)
	{
		g_string_append_printf(desc, "x264enc bitrate=%d speed-preset=%d key-int-max=%d ! ", frame->GetVideoBitrate(), frame->GetVideoEncoderSpeed(), frame->GetFramerate() * 2);
	}
	else
	{
		g_string_append_printf(desc, "vtenc_h264 bitrate=%d quality=%f max-keyframe-interval=%d realtime=true ! ", frame->GetVideoBitrate(), frame->GetVideoEncoderSpeed() / 10.0, frame->GetFramerate() * 2);
	}
	g_string_append_printf(desc, "video/x-h264, profile=main ! h264parse ! tee name=tee_264 ");
	
	g_string_append_printf(desc, "audiomixer name=audio_mix ! audioconvert ! audioresample ! ");
	
	if (frame->GetAudioEncoder() > 0)
	{
		int rate = 44100;
		
		if (frame->GetAudioBitrate() / 1000 < 64)
		{
			rate = 11025;
		}
		else if (frame->GetAudioBitrate() / 1000 < 112)
		{
			rate = 22050;
		}
		
		g_string_append_printf(desc, "lamemp3enc bitrate=%d target=bitrate ! audio/mpeg, rate=%d ! mpegaudioparse ! tee name=tee_aac ", frame->GetAudioBitrate() / 1000, rate);
	}
	else
	{
		g_string_append_printf(desc, "voaacenc bitrate=%d ! audio/mpeg, channels=2 ! aacparse ! tee name=tee_aac ", frame->GetAudioBitrate());
	}
	
	if (frame->GetAudioSystemDevice() != 0)
	{
#if defined __APPLE__
		g_string_append_printf(desc, "osxaudiosrc device=%d ! ", frame->GetAudioSystemDevice());
#elif defined _WIN32
		g_string_append_printf(desc, "directsoundsrc device-name=\"%s\" ! ", frame->GetAudioSystemDeviceName());
#else
		g_string_append_printf(desc, "osxaudiosrc device=%d ! ", frame->GetAudioSystemDevice());
#endif
		g_string_append_printf(desc, "queue ! audioconvert ! audioresample ! audio_mix. ");
	}
	
	if (frame->GetAudioDevice() != 0)
	{
#if defined __APPLE__
		g_string_append_printf(desc, "osxaudiosrc device=%d ", frame->GetAudioDevice());
#elif defined _WIN32
		g_string_append_printf(desc, "directsoundsrc device-name=\"%s\" ", frame->GetAudioDeviceName());
#else
		g_string_append_printf(desc, "osxaudiosrc device=%d ", frame->GetAudioDevice());
#endif
		g_string_append_printf(desc, "provide-clock=%s ! queue ! volume name=volume ! audioconvert ! audioresample ! audio_mix. ", frame->GetAudioSystemDevice() != 0 ? "false" : "true");
	}
	
	if (frame->GetAudioSystemDevice() == 0 && frame->GetAudioDevice() == 0)
	{
		g_string_append_printf(desc, "audiotestsrc is-live=true wave=silence ! queue ! audio_mix. ");
	}
	
	if (frame->GetUrl() != NULL)
	{
		g_string_append_printf(desc, "tee_aac. ! queue max-size-time=0 max-size-buffers=0 max-size-time=4000000000 leaky=upstream ! flv_mux. ");
		g_string_append_printf(desc, "tee_264. ! queue ! flvmux streamable=true name=flv_mux ! rtmpsink location=\"%s\" ", frame->GetUrl());
	}
	
	if (frame->GetRecordingDirectory() != NULL)
	{
		g_string_append_printf(desc, "tee_aac. ! queue max-size-time=0 max-size-buffers=0 max-size-time=4000000000 leaky=upstream ! mp4_mux. ");
		g_string_append_printf(desc, "tee_264. ! queue ! mp4mux name=mp4_mux ! filesink location=\"%s/mincer_%s.mp4\"", frame->GetRecordingDirectory(), g_date_time_format(date, "%Y-%m-%d_%H%M%S"));
	}
	
	g_date_time_unref(date);
	
	m_pipeline = gst_parse_launch(desc->str, &err);
	g_string_free(desc, TRUE);
	
	if (err != NULL)
	{
		wxGetApp().CallAfter(&myApp::GStreamerError, err->message);
		g_error_free(err);
		
		gst_object_unref(m_pipeline);
		m_pipeline = NULL;
		
		return;
	}
	
	bus = gst_pipeline_get_bus(GST_PIPELINE(m_pipeline));
	gst_bus_set_sync_handler(bus, bus_callback, NULL, NULL);
	gst_object_unref(bus);
	
	gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
}

void GStreamer::Stop()
{
	if (m_pipeline == NULL)
	{
		return;
	}
	
	if (gst_element_get_state(m_pipeline, NULL, NULL, GST_CLOCK_TIME_NONE) == GST_STATE_CHANGE_SUCCESS)
	{
		GstBus *bus = gst_pipeline_get_bus(GST_PIPELINE(m_pipeline));
		
		gst_bus_set_sync_handler(bus, NULL, NULL, NULL);
		gst_element_send_event(m_pipeline, gst_event_new_eos());
		
		GstMessage *msg = gst_bus_timed_pop_filtered(bus, GST_CLOCK_TIME_NONE, GST_MESSAGE_EOS);
		
		gst_message_unref(msg);
		gst_object_unref(bus);
	}
	
	gst_element_set_state(m_pipeline, GST_STATE_NULL);
	
	gst_object_unref(m_pipeline);
	m_pipeline = NULL;
}

void GStreamer::SetMute(bool mute)
{
	GstElement *elem = gst_bin_get_by_name(GST_BIN(m_pipeline), "volume");
	
	if (elem)
	{
		g_object_set(elem, "mute", mute, NULL);
		g_object_unref(elem);
	}
}

bool GStreamer::IsRunning()
{
	return m_pipeline != NULL ? true : false;
}

float GStreamer::GetFps()
{
	GstElement *elem = gst_bin_get_by_name(GST_BIN(m_pipeline), "video_src");
	gint fps = 0;
	
	if (elem)
	{
		g_object_get(elem, "fps", &fps, NULL);
		g_object_unref(elem);
		
		if (fps < 0)
		{
			fps = 0;
		}
	}
	
	return fps;
}
