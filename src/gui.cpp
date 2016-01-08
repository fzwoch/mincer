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

#include "gui.h"
#include "app.h"
#include <wx/config.h>

static const wxString encoder_speeds[] =
{
	"",
	"Ultra Fast",
	"Super Fast",
	"Very Fast",
	"Faster",
	"Fast",
	"Medium",
	"Slow",
	"Slower",
	"Very Slow",
	"Placebo"
};

myFrame::myFrame()
	: wxFrame(NULL, wxID_ANY, "Mincer", wxDefaultPosition, wxDefaultSize, wxDEFAULT_FRAME_STYLE & ~(wxRESIZE_BORDER | wxMAXIMIZE_BOX))
	, m_timer(this)
{
	wxBoxSizer *sizer;
	wxBoxSizer *sizer_tmp;
	
	m_panel = new wxPanel(this);
	
	m_url_label = new wxStaticText(m_panel, wxID_ANY, "RTMP Streaming URL");
	m_url = new wxTextCtrl(m_panel, wxID_ANY);
	m_url_hidden = new wxTextCtrl(m_panel, wxID_ANY, wxEmptyString, wxDefaultPosition, wxDefaultSize, wxTE_PASSWORD);
	
	m_video_label = new wxStaticText(m_panel, wxID_ANY, "Video Input");
	m_video_performance_label = new wxStaticText(m_panel, wxID_ANY, "0 frames per second");
	m_video = new wxChoice(m_panel, wxID_ANY);

	m_resolution_label = new wxStaticText(m_panel, wxID_ANY, "Video Resolution");
	m_resolution = new wxChoice(m_panel, wxID_ANY);
	
	m_framerate_label = new wxStaticText(m_panel, wxID_ANY, "Framerate");
	m_framerate = new wxChoice(m_panel, wxID_ANY);
	
	m_video_encoder_label = new wxStaticText(m_panel, wxID_ANY, "Video Encoder");
	m_video_encoder = new wxChoice(m_panel, wxID_ANY);

	m_audio_encoder_label = new wxStaticText(m_panel, wxID_ANY, "Audio Encoder");
	m_audio_encoder = new wxChoice(m_panel, wxID_ANY);
	
	m_video_speed_label = new wxStaticText(m_panel, wxID_ANY, "Video Encoder Speed");
	m_video_speed = new wxSlider(m_panel, wxID_ANY, 1, 1, 10, wxDefaultPosition, wxDefaultSize, wxSL_HORIZONTAL | wxSL_AUTOTICKS);
	
	m_video_bitrate_label = new wxStaticText(m_panel, wxID_ANY, "Video Bitrate");
	m_video_bitrate = new wxSlider(m_panel, wxID_ANY, 300, 300, 5000, wxDefaultPosition, wxDefaultSize, wxSL_HORIZONTAL | wxSL_AUTOTICKS);
	
	m_audio_label = new wxStaticText(m_panel, wxID_ANY, "Audio Input");
	m_system_audio_label = new wxStaticText(m_panel, wxID_ANY, "System audio capture not found");
	m_audio = new wxChoice(m_panel, wxID_ANY);
	m_mute = new wxToggleButton(m_panel, wxID_ANY, "Mute");
	
	m_audio_bitrate_label = new wxStaticText(m_panel, wxID_ANY, "Audio Bitrate");
	m_audio_bitrate = new wxSlider(m_panel, wxID_ANY, 2, 2, 20, wxDefaultPosition, wxDefaultSize, wxSL_HORIZONTAL | wxSL_AUTOTICKS);
	
	m_recordings_label = new wxStaticText(m_panel, wxID_ANY, "Recordings");
	m_recordings = new wxButton(m_panel, wxID_ANY, "-- Disabled --");
	
	m_elapsed = new wxStaticText(m_panel, wxID_ANY, "--:--:--");
	m_start = new wxButton(m_panel, wxID_ANY, "Start");
	
	m_main_sizer = new wxBoxSizer(wxVERTICAL);
	m_sizer = new wxBoxSizer(wxVERTICAL);
	
	/*
	 * events
	 */
	
	m_video_speed->Bind(wxEVT_SLIDER, &myFrame::OnVideoSpeed, this);
	m_video_bitrate->Bind(wxEVT_SLIDER, &myFrame::OnVideoBitrate, this);
	m_mute->Bind(wxEVT_BUTTON, &myApp::OnMute, wxGetApp());
	m_audio_bitrate->Bind(wxEVT_SLIDER, &myFrame::OnAudioBitrate, this);
	m_recordings->Bind(wxEVT_BUTTON, &myFrame::OnRecordings, this);
	m_start->Bind(wxEVT_BUTTON, &myApp::StartStream, wxGetApp());
	
	Bind(wxEVT_TIMER, &myFrame::OnTimer, this);
	Bind(wxEVT_CLOSE_WINDOW, &myApp::CloseGui, wxGetApp());
	
	/*
	 * customize
	 */
	
	m_url->SetHint("rtmp://live.twitch.tv/app/<streamkey>");
	m_url_hidden->Hide();
	m_url_hidden->Disable();
	
#ifdef __APPLE__
	unsigned int device_count;
	
	CGGetActiveDisplayList(0, NULL, &device_count);
	
	for (int i = 0; i < device_count; i++)
	{
		switch (i)
		{
			case 0:
				m_video->Append("Primary Desktop");
				break;
			case 1:
				m_video->Append("Secondary Desktop");
				break;
			case 2:
				m_video->Append("Tertiary Desktop");
				break;
			default:
				m_video->Append(wxString::Format("Desktop %d", i + 1));
				break;
		}
	}
#endif
	
	for (int i = 0; i < sizeof(resolutions) / sizeof(resolution_pair); i++)
	{
		char tmp[32];
		
		snprintf(tmp, sizeof(tmp), "%dx%d", resolutions[i].width, resolutions[i].height);
		
		m_resolution->Append(wxString::Format("%-12s\t%s", tmp, resolutions[i].aspect_ratio));
	}
	
	for (int i = 5; i <= 60; i += 5)
	{
		m_framerate->Append(wxString::Format("%d", i));
	}
	
	m_video_encoder->Append("Software");
#ifdef __APPLE__
	m_video_encoder->Append("Hardware");
#endif
	
	m_audio_encoder->Append("AAC");
	m_audio_encoder->Append("MP3");
	
	m_audio_capture_id = 0;
	m_audio->Append("None");
	
#ifdef __APPLE__
	unsigned int size = 0;
	AudioDeviceID *audio_device_id = m_audio_device_ids;
	
	audio_device_id[0] = 0;
	audio_device_id++;
	
	AudioObjectPropertyAddress addr =
	{
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size);
	AudioDeviceID *devices = (AudioDeviceID*)malloc(size);
	AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);
	
	device_count = size / sizeof(AudioDeviceID);
	
	for (gint i = 0; i < device_count && i < sizeof(m_audio_device_ids) / sizeof(AudioDeviceID); i++)
	{
		CFStringRef name = NULL;
		
		addr.mSelector = kAudioDevicePropertyDeviceNameCFString;
		addr.mScope = kAudioObjectPropertyScopeGlobal;
		
		size = sizeof(CFStringRef);
		AudioObjectGetPropertyData(devices[i], &addr, 0, NULL, &size, &name);
		
		addr.mSelector = kAudioDevicePropertyStreams;
		addr.mScope = kAudioDevicePropertyScopeInput;
		
		AudioObjectGetPropertyDataSize(devices[i], &addr, 0, NULL, &size);
		
		if (size)
		{
			m_audio->Append(wxCFStringRef::AsString(name));
			
			audio_device_id[0] = devices[i];
			audio_device_id++;
			
			if (m_audio_capture_id == 0)
			{
				if (wxCFStringRef::AsString(name) == "Soundflower (2ch)")
				{
					m_audio_capture_id = devices[i];
					
					m_system_audio_label->SetLabel("System audio capture via Soundflower");
				}
				else if (wxCFStringRef::AsString(name) == "WavTap")
				{
					m_audio_capture_id = devices[i];
					
					m_system_audio_label->SetLabel("System audio capture via WavTap");
				}
				else if (wxCFStringRef::AsString(name) == "iShowU Audio Capture")
				{
					m_audio_capture_id = devices[i];
					
					m_system_audio_label->SetLabel("System audio capture via iShowU");
				}
			}
		}
		
		CFRelease(name);
	}
	
	if (devices != NULL)
	{
		free(devices);
	}
#endif
	
	m_mute->Disable();
	
	wxFont font = m_system_audio_label->GetFont();
	font.SetPointSize(font.GetPointSize() - 2);
	
	m_elapsed->SetFont(font);
	m_elapsed->SetForegroundColour(wxTheColourDatabase->Find("GREY"));
	
	font.SetPointSize(font.GetPointSize() - 2);
	
	m_video_performance_label->SetFont(font);
	m_video_performance_label->SetForegroundColour(wxTheColourDatabase->Find("LIGHT GREY"));
	
	m_system_audio_label->SetFont(font);
	m_system_audio_label->SetForegroundColour(wxTheColourDatabase->Find("LIGHT GREY"));
	
	/*
	 * layout
	 */
	
	m_sizer->Add(m_url_label, 0, wxBOTTOM, 5);
	m_sizer->Add(m_url, 0, wxEXPAND | wxBOTTOM, 15);
	m_sizer->Add(m_url_hidden, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer = new wxBoxSizer(wxHORIZONTAL);
	
		sizer->Add(m_video_label, 1);
		sizer->Add(m_video_performance_label, 0, wxALIGN_CENTER_VERTICAL);
	
	m_sizer->Add(sizer, 0, wxEXPAND | wxBOTTOM, 5);
	m_sizer->Add(m_video, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer = new wxBoxSizer(wxVERTICAL);
	
		sizer->Add(m_resolution_label, 0, wxBOTTOM, 5);
		sizer->Add(m_resolution, 0, wxEXPAND | wxBOTTOM, 15);
	
		sizer->Add(m_video_encoder_label, 0, wxBOTTOM, 5);
		sizer->Add(m_video_encoder, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer_tmp = new wxBoxSizer(wxHORIZONTAL);
	
	sizer_tmp->Add(sizer, 1, wxEXPAND | wxRIGHT, 8);
	
	sizer = new wxBoxSizer(wxVERTICAL);
	
		sizer->Add(m_framerate_label, 0, wxBOTTOM, 5);
		sizer->Add(m_framerate, 0, wxEXPAND | wxBOTTOM, 15);
	
		sizer->Add(m_audio_encoder_label, 0, wxBOTTOM, 5);
		sizer->Add(m_audio_encoder, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer_tmp->Add(sizer, 1, wxEXPAND | wxLEFT, 8);
	
	m_sizer->Add(sizer_tmp, 0, wxEXPAND);

	m_sizer->Add(m_video_speed_label, 0, wxBOTTOM, 5);
	m_sizer->Add(m_video_speed, 0, wxEXPAND | wxBOTTOM, 15);
	
	m_sizer->Add(m_video_bitrate_label, 0, wxBOTTOM, 5);
	m_sizer->Add(m_video_bitrate, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer = new wxBoxSizer(wxHORIZONTAL);
	
		sizer->Add(m_audio_label, 1);
		sizer->Add(m_system_audio_label, 0, wxALIGN_CENTER_VERTICAL);
	
	m_sizer->Add(sizer, 0, wxEXPAND | wxBOTTOM, 5);
	
	sizer = new wxBoxSizer(wxHORIZONTAL);
	
		sizer->Add(m_audio, 1);
		sizer->Add(m_mute, 0, wxLEFT, 15);
	
	m_sizer->Add(sizer, 0, wxEXPAND | wxBOTTOM, 15);
	
	m_sizer->Add(m_audio_bitrate_label, 0, wxBOTTOM, 5);
	m_sizer->Add(m_audio_bitrate, 0, wxEXPAND | wxBOTTOM, 15);
	
	m_sizer->Add(m_recordings_label, 0, wxBOTTOM, 5);
	m_sizer->Add(m_recordings, 0, wxEXPAND | wxBOTTOM, 15);
	
	sizer = new wxBoxSizer(wxHORIZONTAL);
	
		sizer->Add(m_elapsed, 1, wxALIGN_CENTER_VERTICAL);
		sizer->Add(m_start, 0);
	
	m_sizer->Add(sizer, 0, wxEXPAND);
	
	m_main_sizer->Add(m_sizer, 0, wxEXPAND | wxALL, 15);
	m_main_sizer->SetMinSize(wxSize(360, wxDefaultCoord));
	
	m_panel->SetSizerAndFit(m_main_sizer);
	
	Fit();
	
#ifdef __APPLE__
	SetBackgroundColour(wxColour(0xe8, 0xe8, 0xe8));
#endif
	
	/*
	 * load config
	 */
	
	wxConfig config("Mincer");
	
	m_url->SetValue(config.Read("url", ""));
	m_video->SetSelection(config.ReadLong("video_device", 0));
	m_resolution->SetSelection(config.ReadLong("resolution", 0));
	m_framerate->SetSelection(config.ReadLong("framerate", 0));
	m_video_encoder->SetSelection(config.ReadLong("video_encoder", 0));
	m_audio_encoder->SetSelection(config.ReadLong("audio_encoder", 0));
	m_video_speed->SetValue(config.ReadLong("video_speed", 0));
	m_video_bitrate->SetValue(config.ReadLong("video_bitrate", 0));
	m_audio->SetSelection(config.ReadLong("audio_device", 0));
	m_audio_bitrate->SetValue(config.ReadLong("audio_bitrate", 0));
	m_recordings->SetLabel(config.Read("recordings", ""));
	
	if (m_recordings->GetLabel().empty())
	{
		m_recordings->SetLabel("-- Disabled --");
	}
	
	SetPosition(wxPoint(config.ReadLong("pos_x", wxDefaultCoord), config.ReadLong("pos_y", wxDefaultCoord)));
	
	wxCommandEvent event;
	
	OnVideoSpeed(event);
	OnVideoBitrate(event);
	OnAudioBitrate(event);
}

myFrame::~myFrame()
{
	wxConfig config("Mincer");
	
	config.Write("url", m_url->GetValue());
	config.Write("video_device", m_video->GetSelection());
	config.Write("resolution", m_resolution->GetSelection());
	config.Write("framerate", m_framerate->GetSelection());
	config.Write("video_encoder", m_video_encoder->GetSelection());
	config.Write("audio_encoder", m_audio_encoder->GetSelection());
	config.Write("video_speed", m_video_speed->GetValue());
	config.Write("video_bitrate", m_video_bitrate->GetValue());
	config.Write("audio_device", m_audio->GetSelection());
	config.Write("audio_bitrate", m_audio_bitrate->GetValue());
	config.Write("recordings", m_recordings->GetLabel() == "-- Disabled --" ? "" : m_recordings->GetLabel());
	
	config.Write("pos_x", GetPosition().x);
	config.Write("pos_y", GetPosition().y);
}

void myFrame::OnVideoSpeed(wxCommandEvent &event)
{
	m_video_speed_label->SetLabel(wxString::Format("Video Encoder Speed - %s", encoder_speeds[m_video_speed->GetValue()]));
}

void myFrame::OnVideoBitrate(wxCommandEvent &event)
{
	m_video_bitrate_label->SetLabel(wxString::Format("Video Bitrate - %d kbps", m_video_bitrate->GetValue()));
}

void myFrame::OnAudioBitrate(wxCommandEvent &event)
{
	m_audio_bitrate_label->SetLabel(wxString::Format("Audio Bitrate - %d kbps", m_audio_bitrate->GetValue() * 16));
}

void myFrame::OnRecordings(wxCommandEvent &event)
{
	wxDirDialog *dialog = new wxDirDialog(this, wxEmptyString);
	
	dialog->Bind(wxEVT_WINDOW_MODAL_DIALOG_CLOSED, &myFrame::OnRecordingsFinish, this);
	dialog->ShowWindowModal();
}

void myFrame::OnRecordingsFinish(wxWindowModalDialogEvent &event)
{
	wxDirDialog *dialog = (wxDirDialog*)event.GetDialog();
				   
	if (event.GetReturnCode() == wxID_CANCEL)
	{
		m_recordings->SetLabel("-- Disabled --");
	}
	else
	{
		m_recordings->SetLabel(dialog->GetPath());
	}
}

void myFrame::OnTimer(wxTimerEvent &event)
{
	wxTimeSpan duration = wxDateTime::Now() - m_datetime;
	
	m_elapsed->SetLabel(duration.Format("%H:%M:%S"));
}

void myFrame::Start()
{
	m_datetime = wxDateTime::Now();
	m_timer.Start(100);
	
	m_url_hidden->SetValue(m_url->GetValue());
	
	m_url->Hide();
	m_url_hidden->Show();
	
	m_sizer->Layout();
	
	m_video->Disable();
	m_resolution->Disable();
	m_framerate->Disable();
	m_video_encoder->Disable();
	m_audio_encoder->Disable();
	m_video_speed->Disable();
	m_video_bitrate->Disable();
	m_audio->Disable();
	m_audio_bitrate->Disable();
	m_recordings->Disable();
	
	if (m_audio->GetSelection() > 0)
	{
		m_mute->Enable();
	}
	
	m_start->SetLabel("Stop");
	
	m_start->Unbind(wxEVT_BUTTON, &myApp::StartStream, wxGetApp());
	m_start->Bind(wxEVT_BUTTON, &myApp::StopStream, wxGetApp());
}

void myFrame::Stop()
{
	m_timer.Stop();
	
	m_url->Show();
	m_url_hidden->Hide();
	
	m_sizer->Layout();
	
	m_video->Enable();
	m_resolution->Enable();
	m_framerate->Enable();
	m_video_encoder->Enable();
	m_audio_encoder->Enable();
	m_video_speed->Enable();
	m_video_bitrate->Enable();
	m_audio->Enable();
	m_audio_bitrate->Enable();
	m_recordings->Enable();
	
	m_mute->Disable();
	
	m_start->SetLabel("Start");
	
	m_start->Unbind(wxEVT_BUTTON, &myApp::StopStream, wxGetApp());
	m_start->Bind(wxEVT_BUTTON, &myApp::StartStream, wxGetApp());
	
	m_elapsed->SetLabel("--:--:--");
}