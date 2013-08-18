/*
 * osxaacencode
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

#include <gst/gst.h>
#include <gst/base/gstbasetransform.h>
#include <Cocoa/Cocoa.h>

typedef struct {
	GstBaseTransform element;
} GstOsxAacEncode;

typedef struct {
	GstBaseTransformClass parent_class;
} GstOsxAacEncodeClass;

#define GST_TYPE_OSX_AAC_ENCODE (gst_osx_aac_encode_get_type())
#define GST_OSX_AAC_ENCODE(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_OSX_VAAC_ENCODE,GstOsxAacEncode))
#define GST_OSX_AAC_ENCODE_CLASS(class) (G_TYPE_CHECK_CLASS_CAST((class),GST_TYPE_OSX_AAC_ENCODE,GstOsxAacEncodeClass))
#define GST_IS_OSX_AAC_ENCODE(obj) (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_OSX_AAC_ENCODE))
#define GST_IS_OSX_AAC_ENCODE_CLASS(class) (G_TYPE_CHECK_CLASS_TYPE((class),GST_TYPE_OSX_AAC_ENCODE))

G_DEFINE_TYPE(GstOsxAacEncode, gst_osx_aac_encode, GST_TYPE_BASE_TRANSFORM);

static GstStaticPadTemplate sink_template = GST_STATIC_PAD_TEMPLATE
(
	"sink",
	GST_PAD_SINK,
	GST_PAD_ALWAYS,
	GST_STATIC_CAPS
	(
		"audio/x-raw, "
		"format = S16LE, "
		"rate = 44100, "
		"channels = 2, "
		"layout = interleaved"
	)
);

static GstStaticPadTemplate src_template = GST_STATIC_PAD_TEMPLATE
(
	"src",
	GST_PAD_SRC,
	GST_PAD_ALWAYS,
	GST_STATIC_CAPS
	(
		"audio/mpeg, "
		"mpegversion = 4, "
		"rate = 44100, "
		"channels = 2, "
		"stream-format = raw, "
		"base-profile = lc"
	)
);

static GstCaps* gst_osx_aac_encode_transform_caps(GstBaseTransform *trans, GstPadDirection direction, GstCaps *caps, GstCaps *filter)
{
	GstPadTemplate *pad_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(trans), "src");
	GstCaps *new_caps = gst_caps_copy(gst_pad_template_get_caps(pad_template));
	
	return new_caps;
}

static gboolean gst_osx_aac_encode_set_caps(GstBaseTransform *trans, GstCaps *incaps, GstCaps *outcaps)
{
	return TRUE;
}

static GstFlowReturn gst_osx_aac_encode_transform(GstBaseTransform *trans, GstBuffer *inbuf, GstBuffer *outbuf)
{
	GstMapInfo info_in;
	GstMapInfo info_out;
	
	gst_buffer_map(inbuf, &info_in, GST_MAP_READ);
	gst_buffer_map(outbuf, &info_out, GST_MAP_WRITE);
	
	gst_buffer_unmap(inbuf, &info_in);
	gst_buffer_unmap(outbuf, &info_out);
	
	return GST_FLOW_OK;
}

static void gst_osx_aac_encode_class_init(GstOsxAacEncodeClass *class)
{
	gst_element_class_set_static_metadata
	(
		GST_ELEMENT_CLASS(class),
		"OS X AAC Encode",
		"Audio/Encoder",
		"Encodes audio to AAC using CoreAudio",
		"Florian Zwoch <fzwoch@gmail.com>"
	);
	
	gst_element_class_add_pad_template(GST_ELEMENT_CLASS(class), gst_static_pad_template_get(&sink_template));
	gst_element_class_add_pad_template(GST_ELEMENT_CLASS(class), gst_static_pad_template_get(&src_template));
	
	GST_BASE_TRANSFORM_CLASS(class)->transform = gst_osx_aac_encode_transform;
	GST_BASE_TRANSFORM_CLASS(class)->transform_caps = gst_osx_aac_encode_transform_caps;
	GST_BASE_TRANSFORM_CLASS(class)->set_caps = gst_osx_aac_encode_set_caps;
}

static void gst_osx_aac_encode_init(GstOsxAacEncode *filter)
{
}

static gboolean plugin_init(GstPlugin *plugin)
{
	return gst_element_register(plugin, "osxaacencode", GST_RANK_NONE, GST_TYPE_OSX_AAC_ENCODE);
}

#ifndef PACKAGE
#define PACKAGE "osxaacencode"
#endif

GST_PLUGIN_DEFINE
(
	GST_VERSION_MAJOR,
	GST_VERSION_MINOR,
	osxaacencode,
	"OS X AAC Encode",
	plugin_init,
	"0.0.1",
	"GPL",
	"Mincer",
	"https://github.com/fzwoch/mincer/"
)
