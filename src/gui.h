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

#ifndef __GUI_H__
#define __GUI_H__

#include <wx/wx.h>
#include <wx/tglbtn.h>

#if defined __APPLE__
	#include <CoreGraphics/CoreGraphics.h>
	#include <AudioToolBox/AudioToolbox.h>
	#include <AVFoundation/AVFoundation.h>
	#include <wx/osx/core/cfstring.h>
#elif defined _WIN32
	#include <d3d9.h>
#else
	#include <X11/Xlib.h>
	#include <pulse/pulseaudio.h>
#endif

class myFrame: public wxFrame
{
	wxPanel *m_panel;

	wxStaticText *m_url_label;
	wxTextCtrl *m_url;
	wxTextCtrl *m_url_hidden;
	
	wxStaticText *m_video_label;
	wxStaticText *m_video_performance_label;
	wxChoice *m_video;
	
	wxStaticText *m_resolution_label;
	wxChoice *m_resolution;
	
	wxStaticText *m_framerate_label;
	wxChoice *m_framerate;
	
	wxStaticText *m_video_encoder_label;
	wxChoice *m_video_encoder;
	
	wxStaticText *m_audio_encoder_label;
	wxChoice *m_audio_encoder;
	
	wxStaticText *m_video_speed_label;
	wxSlider *m_video_speed;
	
	wxStaticText *m_video_bitrate_label;
	wxSlider *m_video_bitrate;
	
	wxStaticText *m_audio_label;
	wxStaticText *m_system_audio_label;
	wxChoice *m_audio;
	wxToggleButton *m_mute;
	
	wxStaticText *m_audio_bitrate_label;
	wxSlider *m_audio_bitrate;
	
	wxStaticText *m_recordings_label;
	wxButton *m_recordings;
	
	wxStaticText *m_elapsed;
	wxButton *m_start;
	
	wxBoxSizer *m_main_sizer;
	wxBoxSizer *m_sizer;
	
	unsigned int m_screen_count;
	
#ifdef __APPLE__
	AudioDeviceID m_audio_capture_id;
	AudioDeviceID m_audio_device_ids[32];
#elif _WIN32
	int m_audio_capture_id;
	int m_audio_device_ids[32];
#else
	int m_audio_capture_id;
	int m_audio_device_ids[32];

	char m_audio_device_string[32][1024];

	static void pa_sourcelist_cb(pa_context *c, const pa_source_info *l, int eol, void *userdata);
#endif
	void OnVideoInput(wxCommandEvent &event);
	void OnVideoSpeed(wxCommandEvent &event);
	void OnVideoBitrate(wxCommandEvent &event);
	void OnAudioBitrate(wxCommandEvent &event);
	void OnRecordings(wxCommandEvent &event);
	void OnRecordingsFinish(wxWindowModalDialogEvent &event);
	void OnTimer(wxTimerEvent &event);
	
	wxTimer m_timer;
	wxDateTime m_datetime;
	
	char m_char_buffer[1024];
	
public:
	myFrame();
	virtual ~myFrame();
	
	void Start();
	void Stop();
	
	const char* GetUrl();
	int GetWidth();
	int GetHeight();
	int GetFramerate();
	int GetVideoDevice();
	int GetVideoEncoder();
	int GetVideoEncoderSpeed();
	int GetVideoBitrate();
	int GetAudioEncoder();
	int GetAudioSystemDevice();
	const char* GetAudioSystemDeviceName();
	int GetAudioDevice();
	const char* GetAudioDeviceName();
	int GetAudioBitrate();
	const char* GetRecordingDirectory();
	bool GetMute();
	int GetScreenCount();
};

#endif // __GUI_H__
