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

#ifdef __APPLE__
	#include <CoreGraphics/CoreGraphics.h>
	#include <AudioToolBox/AudioToolbox.h>
	#include <wx/osx/core/cfstring.h>
#endif

struct resolution_pair {
	int width;
	int height;
	wxString aspect_ratio;
};

const struct resolution_pair resolutions[] =
{
	{640, 360, "16:9"},
	{854, 480, "16:9"},
	{960, 540, "16:9"},
	{1024, 576, "16:9"},
	{1152, 648, "16:9"},
	{1280, 720, "16:9"},
	{1366, 768, "16:9"},
	{1600, 900, "16:9"},
	{1920, 1080, "16:9"},
	
	{640, 400, "16:10"},
	{800, 500, "16:10"},
	{960, 600, "16:10"},
	{1024, 640, "16:10"},
	{1152, 720, "16:10"},
	{1280, 800, "16:10"},
	{1440, 900, "16:10"},
	{1680, 1050, "16:10"},
	{1920, 1200, "16:10"},
	
	{640, 480, "4:3"},
	{800, 600, "4:3"},
	{1024, 768, "4:3"},
	{1152, 864, "4:3"},
	{1280, 960, "4:3"},
	{1400, 1050, "4:3"},
	{1600, 1200, "4:3"}
};

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
	
#ifdef __APPLE__
	AudioDeviceID m_audio_capture_id;
	AudioDeviceID m_audio_device_ids[32];
#endif
	
	void OnVideoSpeed(wxCommandEvent &event);
	void OnVideoBitrate(wxCommandEvent &event);
	void OnAudioBitrate(wxCommandEvent &event);
	void OnRecordings(wxCommandEvent &event);
	void OnRecordingsFinish(wxWindowModalDialogEvent &event);
	void OnTimer(wxTimerEvent &event);
	
	wxTimer m_timer;
	wxDateTime m_datetime;
	
	friend class myApp;
	
public:
	myFrame();
	virtual ~myFrame();
	
	void Start();
	void Stop();
};

#endif // __GUI_H__
