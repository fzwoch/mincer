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
	if (m_frame->GetUrl() == NULL && m_frame->GetRecordingDirectory() == NULL)
	{
		wxMessageDialog *dialog = new wxMessageDialog(m_frame, "No URL or recording option is set.", "Nothing to do", wxOK | wxCENTRE);
		
		dialog->ShowWindowModal();
		
		return;
	}
	
	m_frame->Start();
	m_gstreamer.Start(m_frame);
}

void myApp::StopStream(wxCommandEvent &event)
{
	m_gstreamer.Stop();
	m_frame->Stop();
}

void myApp::OnMute(wxCommandEvent &event)
{
	m_gstreamer.SetMute(m_frame->GetMute());
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
