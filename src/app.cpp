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

#include "app.h"

bool myApp::OnInit()
{
	m_frame = new myFrame();
	
	m_frame->Show();
	
	return true;
}

void myApp::StartStream(wxCommandEvent &event)
{
	struct gstreamer_config config;
	
	if (m_frame->m_url->GetValue().empty() & m_frame->m_recordings->GetLabel() == "-- Disabled --")
	{
		wxMessageDialog *dialog = new wxMessageDialog(m_frame, "No URL or recording option is set.", "Nothing to do", wxOK | wxCENTRE);
		
		dialog->ShowWindowModal();
		
		return;
	}
	
	config.url = m_frame->m_url->GetValue().IsEmpty() ? NULL : strdup(m_frame->m_url->GetValue().mb_str().data());
	config.video_device = m_frame->m_video->GetSelection();
	config.width = resolutions[m_frame->m_resolution->GetSelection()].width;
	config.height = resolutions[m_frame->m_resolution->GetSelection()].height;
	config.framerate = wxAtoi(m_frame->m_framerate->GetString(m_frame->m_framerate->GetSelection()));
	config.video_encoder = m_frame->m_video_encoder->GetString(m_frame->m_video_encoder->GetSelection()) == "Software" ? GST_VIDEO_ENCODER_X264 : GST_VIDEO_ENCODER_HW;
	config.audio_encoder = m_frame->m_audio_encoder->GetString(m_frame->m_audio_encoder->GetSelection()) == "AAC" ? GST_AUDIO_ENCODER_AAC : GST_AUDIO_ENCODER_MP3;
	config.video_speed = m_frame->m_video_speed->GetValue();
	config.video_bitrate = m_frame->m_video_bitrate->GetValue();
	config.audio_system_device = m_frame->m_audio_capture_id;
	config.audio_device = m_frame->m_audio_device_ids[m_frame->m_audio->GetSelection()];
	config.audio_bitrate = m_frame->m_audio_bitrate->GetValue() * 16000;
	config.recording = m_frame->m_recordings->GetLabel() == "-- Disabled --" ? NULL : strdup(m_frame->m_recordings->GetLabel().mb_str().data());
	
	m_frame->Start();
	m_gstreamer.Start(config);
	
	if (config.url)
		free(config.url);
	
	if (config.recording)
		free(config.recording);
}

void myApp::StopStream(wxCommandEvent &event)
{
	m_gstreamer.Stop();
	m_frame->Stop();
}

void myApp::OnMute(wxCommandEvent &event)
{
	m_gstreamer.SetMute(m_frame->m_mute->GetValue());
}

void myApp::GStreamerError(const wxString &message)
{
	wxCommandEvent event;
	
	StopStream(event);
	
	wxMessageDialog *dialog = new wxMessageDialog(m_frame, message, "Mincer error", wxOK | wxCENTRE);
	
	dialog->ShowWindowModal();
}

void myApp::CloseGui(wxCloseEvent &event)
{
	if (m_gstreamer.IsRunning())
	{
		wxMessageDialog *dialog = new wxMessageDialog(m_frame, "Mincer is currently running. Are you sure you want to stop processing and quit the application?", "Quit Mincer?", wxOK | wxCANCEL | wxCENTRE);
		
		dialog->Bind(wxEVT_WINDOW_MODAL_DIALOG_CLOSED, &myApp::CloseGuiFinish, this);
		dialog->ShowWindowModal();
		
		event.Veto();
		
		return;
	}
	
	event.Skip();
}

void myApp::CloseGuiFinish(wxWindowModalDialogEvent &event)
{
	if (event.GetReturnCode() == wxID_CANCEL)
	{
		return;
	}
	
	m_frame->Destroy();
}

IMPLEMENT_APP(myApp)
