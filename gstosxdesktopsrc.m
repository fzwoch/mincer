/*
 * osxdesktopsrc
 *
 * Copyright (C) 2013-2014 Florian Zwoch <fzwoch@gmail.com>
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

#include <gst/gst.h>
#include <gst/base/gstpushsrc.h>
#include <Cocoa/Cocoa.h>

typedef struct {
	GstPushSrc element;
	
	gint width;
	gint height;
	gint framerate_num;
	gint framerate_denom;
	
	gint64 time_next;
	
	gint window_id;
	gint display_id;
} GstOsxDesktopSrc;

typedef struct {
	GstPushSrcClass parent_class;
} GstOsxDesktopSrcClass;

#define GST_TYPE_OSX_DESKTOP_SRC (gst_osx_desktop_src_get_type())
#define GST_OSX_DESKTOP_SRC(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_OSX_DESKTOP_SRC,GstOsxDesktopSrc))
#define GST_OSX_DESKTOP_SRC_CLASS(class) (G_TYPE_CHECK_CLASS_CAST((class),GST_TYPE_OSX_DESKTOP_SRC,GstOsxDesktopSrcClass))
#define GST_IS_OSX_DESKTOP_SRC(obj) (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_OSX_DESKTOP_SRC))
#define GST_IS_OSX_DESKTOP_SRC_CLASS(class) (G_TYPE_CHECK_CLASS_TYPE((class),GST_TYPE_OSX_DESKTOP_SRC))

G_DEFINE_TYPE(GstOsxDesktopSrc, gst_osx_desktop_src, GST_TYPE_PUSH_SRC);

static GstStaticPadTemplate src_template = GST_STATIC_PAD_TEMPLATE
(
	"src",
	GST_PAD_SRC,
	GST_PAD_ALWAYS,
	GST_STATIC_CAPS
	(
		"video/x-raw, "
		"format = RGBA, "
		"width = [ 1, 2147483647 ], "
		"height = [ 1, 2147483647 ], "
		"framerate = [ 0/1, 2147483647/1 ]"
	)
);

enum
{
	PROP_0,
	PROP_WINDOW_ID,
	PROP_DISPLAY_ID
};

static void gst_osx_desktop_src_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	switch (prop_id)
	{
		case PROP_WINDOW_ID:
			GST_OSX_DESKTOP_SRC(object)->window_id = g_value_get_int(value);
			break;
		case PROP_DISPLAY_ID:
		{
			guint num;
			CGDirectDisplayID *displays;
			
			CGGetActiveDisplayList(0, NULL, &num);
			
			displays = malloc(num * sizeof(CGDirectDisplayID));
			if (displays == NULL)
			{
				break;
			}
			
			CGGetActiveDisplayList(num, displays, &num);
			
			if (g_value_get_int(value) < num)
			{
				GST_OSX_DESKTOP_SRC(object)->display_id = displays[g_value_get_int(value)];
			}
			
			free(displays);
			
			break;
		}
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
			break;
	}
}

static void gst_osx_desktop_src_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	switch (prop_id)
	{
		case PROP_WINDOW_ID:
			g_value_set_int(value, GST_OSX_DESKTOP_SRC(object)->window_id);
			break;
		case PROP_DISPLAY_ID:
			g_value_set_int(value, GST_OSX_DESKTOP_SRC(object)->display_id);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
			break;
	}
}

static GstCaps* gst_osx_desktop_src_get_caps(GstBaseSrc *src, GstCaps *filter)
{
	GstPadTemplate *pad_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(src), "src");
	GstCaps *caps = gst_caps_copy(gst_pad_template_get_caps(pad_template));
	
	gst_caps_set_simple(caps, "width", G_TYPE_INT, GST_OSX_DESKTOP_SRC(src)->width, NULL); 
	gst_caps_set_simple(caps, "height", G_TYPE_INT, GST_OSX_DESKTOP_SRC(src)->height, NULL); 
	
	return caps;
}

static gboolean gst_osx_desktop_src_set_caps(GstBaseSrc *src, GstCaps *caps)
{
	gint num = 0;
	gint denom = 1;
	
	gst_structure_get_fraction(gst_caps_get_structure(caps, 0), "framerate", &num, &denom);
	
	if (num)
	{
		GST_OSX_DESKTOP_SRC(src)->framerate_num = num;
		GST_OSX_DESKTOP_SRC(src)->framerate_denom = denom;
	}
	
	return TRUE;
}

static GstFlowReturn gst_osx_desktop_src_fill(GstPushSrc *src, GstBuffer *buf)
{
	GstMapInfo info;
	CGImageRef img = NULL;
	size_t width;
	size_t height;
	
	CGContextRef ctx;
	
	if (GST_OSX_DESKTOP_SRC(src)->time_next == -1)
	{
		GST_OSX_DESKTOP_SRC(src)->time_next = g_get_monotonic_time();
	}
	
	for (;;)
	{
		gint64 time_cur = g_get_monotonic_time();
		
		if (time_cur > GST_OSX_DESKTOP_SRC(src)->time_next)
		{
			buf->duration = 1000000000LL / (GST_OSX_DESKTOP_SRC(src)->framerate_num / GST_OSX_DESKTOP_SRC(src)->framerate_denom);
			
			while (GST_OSX_DESKTOP_SRC(src)->time_next < time_cur)
			{
				GST_OSX_DESKTOP_SRC(src)->time_next += 1000000LL / (GST_OSX_DESKTOP_SRC(src)->framerate_num / GST_OSX_DESKTOP_SRC(src)->framerate_denom);
			}
			
			break;
		}
		
		g_usleep(1000);
	}
	
	if (GST_OSX_DESKTOP_SRC(src)->window_id > 0)
	{
		img = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, GST_OSX_DESKTOP_SRC(src)->window_id, kCGWindowImageBoundsIgnoreFraming | kCGWindowImageShouldBeOpaque);
	}
	else if (GST_OSX_DESKTOP_SRC(src)->display_id > 0)
	{
		img = CGDisplayCreateImage(GST_OSX_DESKTOP_SRC(src)->display_id);
	}
	
	if (img == NULL)
	{
		img = CGDisplayCreateImage(CGMainDisplayID());
	}
	
	width = CGImageGetWidth(img);
	height = CGImageGetHeight(img);
	
	if (width != GST_OSX_DESKTOP_SRC(src)->width || height != GST_OSX_DESKTOP_SRC(src)->height)
	{
		GstPadTemplate *pad_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(src), "src");
		GstCaps *caps = gst_caps_copy(gst_pad_template_get_caps(pad_template));
		GstEvent *event;
		
		gst_caps_set_simple(caps, "width", G_TYPE_INT, width, NULL);
		gst_caps_set_simple(caps, "height", G_TYPE_INT, height, NULL);
		gst_caps_set_simple(caps, "framerate", GST_TYPE_FRACTION, GST_OSX_DESKTOP_SRC(src)->framerate_num, GST_OSX_DESKTOP_SRC(src)->framerate_denom, NULL);
		
		event = gst_event_new_caps(caps);
		gst_pad_push_event(GST_BASE_SRC_PAD(src), event);
		
		gst_base_src_set_blocksize(GST_BASE_SRC(src), width * height * 4);
		
		GST_OSX_DESKTOP_SRC(src)->width = width;
		GST_OSX_DESKTOP_SRC(src)->height = height;
		
		CGImageRelease(img);
		
		return GST_FLOW_OK;
	}
	
	gst_buffer_map(buf, &info, GST_MAP_WRITE);
	
	ctx = CGBitmapContextCreate
	(
		info.data,
		width,
		height,
		CGImageGetBitsPerComponent(img),
		CGImageGetBytesPerRow(img),
		CGImageGetColorSpace(img),
		(CGBitmapInfo)kCGImageAlphaNoneSkipLast
	);
	
	CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), img);
	CGImageRelease(img);
	
	if (CGCursorIsVisible())
	{
		@autoreleasepool
		{
			NSRect rect;
			NSCursor *cursor = [NSCursor currentSystemCursor];
			NSImage *cursor_img = [cursor image];
			
			rect.size = [cursor_img size];
			rect.origin = [NSEvent mouseLocation];
			
			rect.origin.x -= [cursor hotSpot].x;
			rect.origin.y -= [cursor_img size].height - [cursor hotSpot].y;
			
			if (GST_OSX_DESKTOP_SRC(src)->display_id != 0)
			{
				CGRect ref_rect = CGDisplayBounds(CGMainDisplayID());
				CGRect adj_rect = CGDisplayBounds(GST_OSX_DESKTOP_SRC(src)->display_id);
				
				rect.origin.x -= adj_rect.origin.x;
				rect.origin.y -= (ref_rect.size.height - adj_rect.size.height) - adj_rect.origin.y;
			}
			
			CGContextDrawImage(ctx, NSRectToCGRect(rect), [cursor_img CGImageForProposedRect:NULL context:NULL hints:NULL]);
		}
	}
	
	CGContextRelease(ctx);
	
	gst_buffer_unmap(buf, &info);
	
	return GST_FLOW_OK;
}

static void gst_osx_desktop_src_class_init(GstOsxDesktopSrcClass *class)
{
	gst_element_class_set_static_metadata
	(
		GST_ELEMENT_CLASS(class),
		"OS X Desktop Source",
		"Capture/Video",
		"Captures OS X Desktop or Windows",
		"Florian Zwoch <fzwoch@gmail.com>"
	);
	
	gst_element_class_add_pad_template(GST_ELEMENT_CLASS(class), gst_static_pad_template_get(&src_template));
	
	GST_BASE_SRC_CLASS(class)->get_caps = gst_osx_desktop_src_get_caps;
	GST_BASE_SRC_CLASS(class)->set_caps = gst_osx_desktop_src_set_caps;
	GST_PUSH_SRC_CLASS(class)->fill = gst_osx_desktop_src_fill;
	G_OBJECT_CLASS(class)->set_property = gst_osx_desktop_src_set_property;
	G_OBJECT_CLASS(class)->get_property = gst_osx_desktop_src_get_property;
	
	g_object_class_install_property(G_OBJECT_CLASS(class), PROP_WINDOW_ID, g_param_spec_int("window-id", "Window ID", "Captures a specific window only", 0, G_MAXINT, 0, G_PARAM_READABLE | G_PARAM_WRITABLE));
	g_object_class_install_property(G_OBJECT_CLASS(class), PROP_DISPLAY_ID, g_param_spec_int("display-id", "Display ID", "Captures a specific display", 0, G_MAXINT, 0, G_PARAM_READABLE | G_PARAM_WRITABLE));
}

static void gst_osx_desktop_src_init(GstOsxDesktopSrc *filter)
{
	CGImageRef img = NULL;
	
	if (filter->window_id > 0)
	{
		img = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, filter->window_id, kCGWindowImageBoundsIgnoreFraming | kCGWindowImageShouldBeOpaque);
	}
	else if (filter->display_id > 0)
	{
		img = CGDisplayCreateImage(filter->display_id);
	}
	
	if (img == NULL)
	{
		img = CGDisplayCreateImage(CGMainDisplayID());
	}
	
	filter->width = CGImageGetWidth(img);
	filter->height = CGImageGetHeight(img);
	
	CGImageRelease(img);
	
	filter->framerate_num = 30;
	filter->framerate_denom = 1;
	
	filter->time_next = -1;
	
	gst_base_src_set_format(GST_BASE_SRC(filter), GST_FORMAT_TIME);
	gst_base_src_set_do_timestamp(GST_BASE_SRC(filter), TRUE);
	gst_base_src_set_blocksize(GST_BASE_SRC(filter), filter->width * filter->height * 4);
}

static gboolean plugin_init(GstPlugin *plugin)
{
	return gst_element_register(plugin, "osxdesktopsrc", GST_RANK_NONE, GST_TYPE_OSX_DESKTOP_SRC);
}

#ifndef PACKAGE
#define PACKAGE "osxdesktopsrc"
#endif

GST_PLUGIN_DEFINE
(
	GST_VERSION_MAJOR,
	GST_VERSION_MINOR,
	osxdesktopsrc,
	"OS X Desktop Source",
	plugin_init,
	"0.0.7",
	"GPL",
	"Mincer",
	"https://github.com/fzwoch/mincer/"
)
