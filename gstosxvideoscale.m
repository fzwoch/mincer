/*
 * osxvideoscale
 *
 * Copyright (C) 2013 Florian Zwoch <fzwoch@gmail.com>
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

#define USE_SWSCALE 1

#include <gst/gst.h>
#include <gst/base/gstbasetransform.h>
#if USE_SWSCALE
#include <libswscale/swscale.h>
#else
#include <Cocoa/Cocoa.h>
#endif

typedef struct {
	GstBaseTransform element;
	
	gint width_in;
	gint height_in;
	
	gint width_out;
	gint height_out;
	
#if USE_SWSCALE
	struct SwsContext *sws;
#endif
} GstOsxVideoscale;

typedef struct {
	GstBaseTransformClass parent_class;
} GstOsxVideoscaleClass;

#define GST_TYPE_OSX_VIDEOSCALE (gst_osx_videoscale_get_type())
#define GST_OSX_VIDEOSCALE(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_OSX_VIDEOSCALE,GstOsxVideoscale))
#define GST_OSX_VIDEOSCALE_CLASS(class) (G_TYPE_CHECK_CLASS_CAST((class),GST_TYPE_OSX_VIDEOSCALE,GstOsxVideoscaleClass))
#define GST_IS_OSX_VIDEOSCALE(obj) (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_OSX_VIDEOSCALE))
#define GST_IS_OSX_VIDEOSCALE_CLASS(class) (G_TYPE_CHECK_CLASS_TYPE((class),GST_TYPE_OSX_VIDEOSCALE))

G_DEFINE_TYPE(GstOsxVideoscale, gst_osx_videoscale, GST_TYPE_BASE_TRANSFORM);

static GstStaticPadTemplate sink_template = GST_STATIC_PAD_TEMPLATE
(
	"sink",
	GST_PAD_SINK,
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

static GstCaps* gst_osx_videoscale_transform_caps(GstBaseTransform *trans, GstPadDirection direction, GstCaps *caps, GstCaps *filter)
{	
	GstPadTemplate *pad_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(trans), "src");
	GstCaps *new_caps = gst_caps_copy(gst_pad_template_get_caps(pad_template));

	if (filter)
	{
		gint width = 0;
		gint height = 0;
		
		gst_structure_get_int(gst_caps_get_structure(filter, 0), "width", &width);
		gst_structure_get_int(gst_caps_get_structure(filter, 0), "height", &height);
		
		if (width && height)
		{
			gst_caps_set_simple(new_caps, "width", G_TYPE_INT, width, NULL);
			gst_caps_set_simple(new_caps, "height", G_TYPE_INT, height, NULL);
		}
	}
	
	return new_caps;
}

static gboolean gst_osx_videoscale_set_caps(GstBaseTransform *trans, GstCaps *incaps, GstCaps *outcaps)
{
	gst_structure_get_int(gst_caps_get_structure(incaps, 0), "width", &GST_OSX_VIDEOSCALE(trans)->width_in);
	gst_structure_get_int(gst_caps_get_structure(incaps, 0), "height", &GST_OSX_VIDEOSCALE(trans)->height_in);
	
	gst_structure_get_int(gst_caps_get_structure(outcaps, 0), "width", &GST_OSX_VIDEOSCALE(trans)->width_out);
	gst_structure_get_int(gst_caps_get_structure(outcaps, 0), "height", &GST_OSX_VIDEOSCALE(trans)->height_out);
	
	return TRUE;
}

static GstFlowReturn gst_osx_videoscale_transform(GstBaseTransform *trans, GstBuffer *inbuf, GstBuffer *outbuf)
{
	GstMapInfo info_in;
	GstMapInfo info_out;
	
#if USE_SWSCALE
	const guint8 *src[3] = { NULL };
	gint src_stride[4] = { 0 };
	
	guint8 *dst[3] = { NULL };
	gint dst_stride[4] = { 0 };
#else
	CGContextRef ctx_in;
	CGContextRef ctx_out;
	
	CGImageRef img;
#endif
	
	gst_buffer_map(inbuf, &info_in, GST_MAP_READ);
	gst_buffer_map(outbuf, &info_out, GST_MAP_WRITE);
	
#if USE_SWSCALE
	src[0] = info_in.data;
	src_stride[0] = GST_OSX_VIDEOSCALE(trans)->width_in * 4;
	
	dst[0] = info_out.data;
	dst_stride[0] = GST_OSX_VIDEOSCALE(trans)->width_out * 4;
	
	GST_OSX_VIDEOSCALE(trans)->sws = sws_getCachedContext(GST_OSX_VIDEOSCALE(trans)->sws, GST_OSX_VIDEOSCALE(trans)->width_in, GST_OSX_VIDEOSCALE(trans)->height_in, PIX_FMT_RGB32, GST_OSX_VIDEOSCALE(trans)->width_out, GST_OSX_VIDEOSCALE(trans)->height_out, PIX_FMT_RGB32, SWS_BILINEAR, NULL, NULL, NULL);
	
	sws_scale(GST_OSX_VIDEOSCALE(trans)->sws, src, src_stride, 0, GST_OSX_VIDEOSCALE(trans)->height_in, dst, dst_stride);
#else
	ctx_in = CGBitmapContextCreate
	(
		info_in.data,
		GST_OSX_VIDEOSCALE(trans)->width_in,
		GST_OSX_VIDEOSCALE(trans)->height_in,
		8,
		GST_OSX_VIDEOSCALE(trans)->width_in * 4,
		CGColorSpaceCreateDeviceRGB(),
		kCGImageAlphaNoneSkipLast
	);
	
	img = CGBitmapContextCreateImage(ctx_in);
	
	ctx_out = CGBitmapContextCreate
	(
		info_out.data,
		GST_OSX_VIDEOSCALE(trans)->width_out,
		GST_OSX_VIDEOSCALE(trans)->height_out,
		8,
		GST_OSX_VIDEOSCALE(trans)->width_out * 4,
		CGColorSpaceCreateDeviceRGB(),
		kCGImageAlphaNoneSkipLast
	);
	
	CGContextSetInterpolationQuality(ctx_out, kCGInterpolationMedium);
	CGContextDrawImage(ctx_out, CGRectMake(0, 0, GST_OSX_VIDEOSCALE(trans)->width_out, GST_OSX_VIDEOSCALE(trans)->height_out), img);
	
	CGImageRelease(img);
	CGContextRelease(ctx_in);
	CGContextRelease(ctx_out);
#endif
	
	gst_buffer_unmap(inbuf, &info_in);
	gst_buffer_unmap(outbuf, &info_out);
	
	return GST_FLOW_OK;
}

static gboolean gst_osx_videoscale_stop(GstBaseTransform *trans)
{
#ifdef USE_SWSCALE
	if (GST_OSX_VIDEOSCALE(trans)->sws)
	{
		sws_freeContext(GST_OSX_VIDEOSCALE(trans)->sws);
		GST_OSX_VIDEOSCALE(trans)->sws = NULL;
	}
#endif
	return TRUE;
}

static void gst_osx_videoscale_class_init(GstOsxVideoscaleClass *class)
{
	gst_element_class_set_static_metadata
	(
		GST_ELEMENT_CLASS(class),
		"OS X Videoscale",
		"Video",
		"Scale video using CoreGraphics",
		"Florian Zwoch <fzwoch@gmail.com>"
	);
	
	gst_element_class_add_pad_template(GST_ELEMENT_CLASS(class), gst_static_pad_template_get(&sink_template));
	gst_element_class_add_pad_template(GST_ELEMENT_CLASS(class), gst_static_pad_template_get(&src_template));
	
	GST_BASE_TRANSFORM_CLASS(class)->transform = gst_osx_videoscale_transform;
	GST_BASE_TRANSFORM_CLASS(class)->transform_caps = gst_osx_videoscale_transform_caps;
	GST_BASE_TRANSFORM_CLASS(class)->set_caps = gst_osx_videoscale_set_caps;
	GST_BASE_TRANSFORM_CLASS(class)->stop = gst_osx_videoscale_stop;
	
	GST_BASE_TRANSFORM_CLASS(class)->passthrough_on_same_caps = TRUE;
}

static void gst_osx_videoscale_init(GstOsxVideoscale *filter)
{
	filter->width_in = 0;
	filter->height_in = 0;
	
	filter->width_out = 0;
	filter->height_out = 0;
	
#if USE_SWSCALE
	filter->sws = NULL;
#endif
}

static gboolean plugin_init(GstPlugin *plugin)
{
	return gst_element_register(plugin, "osxvideoscale", GST_RANK_NONE, GST_TYPE_OSX_VIDEOSCALE);
}

#ifndef PACKAGE
#define PACKAGE "osxvideoscale"
#endif

GST_PLUGIN_DEFINE
(
	GST_VERSION_MAJOR,
	GST_VERSION_MINOR,
	osxvideoscale,
	"OS X Videoscale",
	plugin_init,
	"0.0.2",
	"GPL",
	"Mincer",
	"https://github.com/fzwoch/mincer/"
)
