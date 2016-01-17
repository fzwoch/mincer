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

#ifndef __APP_H__
#define __APP_H__

#include <wx/wx.h>
#include "gui.h"
#include "gstreamer.h"

class myApp: public wxApp
{
	virtual bool OnInit();
	
	myFrame *m_frame;
	GStreamer m_gstreamer;
	
public:
	void OnMenu(wxCommandEvent &event);
	
	void StartStream(wxCommandEvent &event);
	void StopStream(wxCommandEvent &event);
	
	void OnMute(wxCommandEvent &event);
	void GStreamerError(const wxString &message);
	
	float GetFps();
	
	void CloseGui(wxCloseEvent &event);
	void CloseGuiFinish(wxWindowModalDialogEvent &event);
};

DECLARE_APP(myApp)

#endif // __APP_H__
