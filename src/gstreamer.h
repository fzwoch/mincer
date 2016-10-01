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
#include "gui.h"

class GStreamer
{
	GstElement *m_pipeline;
	
public:
	GStreamer();
	virtual ~GStreamer();
	
	void Start(myFrame *frame);
	void Stop();
	
	void SetMute(bool mute);
	bool IsRunning();
	float GetFps();
};

#endif // __GSTREAMER_H__
