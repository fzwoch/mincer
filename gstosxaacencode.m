/*
 * osxaacencode
 *
 * Copyright (C) 2013-2015 Florian Zwoch <fzwoch@gmail.com>
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
#include <gst/audio/gstaudioencoder.h>
#include <Cocoa/Cocoa.h>
#include <AudioToolbox/AudioToolbox.h>

typedef struct {
	GstAudioEncoder element;
	
	AudioConverterRef encoder;
	gint bitrate;
} GstOsxAacEncode;

typedef struct {
	GstAudioEncoderClass parent_class;
} GstOsxAacEncodeClass;

#define GST_TYPE_OSX_AAC_ENCODE (gst_osx_aac_encode_get_type())
#define GST_OSX_AAC_ENCODE(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_OSX_AAC_ENCODE,GstOsxAacEncode))
#define GST_OSX_AAC_ENCODE_CLASS(class) (G_TYPE_CHECK_CLASS_CAST((class),GST_TYPE_OSX_AAC_ENCODE,GstOsxAacEncodeClass))
#define GST_IS_OSX_AAC_ENCODE(obj) (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_OSX_AAC_ENCODE))
#define GST_IS_OSX_AAC_ENCODE_CLASS(class) (G_TYPE_CHECK_CLASS_TYPE((class),GST_TYPE_OSX_AAC_ENCODE))

G_DEFINE_TYPE(GstOsxAacEncode, gst_osx_aac_encode, GST_TYPE_AUDIO_ENCODER);

enum
{
	PROP_0,
	PROP_BITRATE,
};

static GstStaticPadTemplate sink_template = GST_STATIC_PAD_TEMPLATE
(
	GST_AUDIO_ENCODER_SINK_NAME,
	GST_PAD_SINK,
	GST_PAD_ALWAYS,
	GST_STATIC_CAPS
	(
		"audio/x-raw, "
		"format = S32LE, "
		"rate = 44100, "
		"channels = 2, "
		"layout = interleaved"
	)
);

static GstStaticPadTemplate src_template = GST_STATIC_PAD_TEMPLATE
(
	GST_AUDIO_ENCODER_SRC_NAME,
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

#define MP4ESDescrTag			0x03
#define MP4DecConfigDescrTag	0x04
#define MP4DecSpecificDescrTag	0x05

static int readDescrLen(UInt8 **buffer)
{
	int len = 0;
	int count = 4;
	
	while (count--)
	{
		int c = *(*buffer)++;
		
		len = (len << 7) | (c & 0x7f);
		
		if (!(c & 0x80))
		{
			break;
		}
	}
	
	return len;
}

static int readDescr(UInt8 **buffer, int *tag)
{
	*tag = *(*buffer)++;
	
	return readDescrLen(buffer);
}

static long ReadESDSDescExt(void *descExt, UInt8 **buffer, UInt32 *size, int versionFlags)
{
	UInt8 *esds = (UInt8*)descExt;
	int tag, len;
	*size = 0;
	
	if (versionFlags)
	{
		esds += 4; // version + flags
	}
	
	readDescr(&esds, &tag);
	esds += 2;     // ID
	
	if (tag == MP4ESDescrTag)
	{
		esds++;    // priority
	}
	
	readDescr(&esds, &tag);
	if (tag == MP4DecConfigDescrTag)
	{
		esds++;    // object type id
		esds++;    // stream type
		esds += 3; // buffer size db
		esds += 4; // max bitrate
		esds += 4; // average bitrate
		
		len = readDescr(&esds, &tag);
		if (tag == MP4DecSpecificDescrTag)
		{
			*buffer = calloc(1, len + 8);
			
			if (*buffer)
			{
				memcpy(*buffer, esds, len);
				*size = len;
			}
		}
	}
	
	return noErr;
}

static void gst_osx_aac_encode_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	switch (prop_id)
	{
	case PROP_BITRATE:
		GST_OSX_AAC_ENCODE(object)->bitrate = g_value_get_int(value);
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void gst_osx_aac_encode_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	switch (prop_id)
	{
	case PROP_BITRATE:
		g_value_set_int(value, GST_OSX_AAC_ENCODE(object)->bitrate);
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static gboolean gst_osx_aac_encode_set_format(GstAudioEncoder *enc, GstAudioInfo *info)
{
	GstPadTemplate *pad_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(enc), GST_AUDIO_ENCODER_SRC_NAME);
	GstCaps *caps = gst_caps_copy(gst_pad_template_get_caps(pad_template));
	GstBuffer *codec_data;
	guint8 *buffer = NULL;
	guint8 data[64];
	UInt32 tmp = sizeof(data);
	
	AudioStreamBasicDescription fmt_in;
	AudioStreamBasicDescription fmt_out;
	
	memset(&fmt_in, 0, sizeof(AudioStreamBasicDescription));
	memset(&fmt_out, 0, sizeof(AudioStreamBasicDescription));
	
	fmt_in.mSampleRate = 44100;
	fmt_in.mFormatID = kAudioFormatLinearPCM;
	fmt_in.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian;
	fmt_in.mBytesPerPacket = 4 * 2;
	fmt_in.mFramesPerPacket = 1;
	fmt_in.mBytesPerFrame = fmt_in.mBytesPerPacket * fmt_in.mFramesPerPacket;
	fmt_in.mChannelsPerFrame = 2;
	fmt_in.mBitsPerChannel = 32;
	
	fmt_out.mFormatID = kAudioFormatMPEG4AAC;
	fmt_out.mSampleRate = 44100;
	fmt_out.mChannelsPerFrame = 2;
	
	AudioConverterNew(&fmt_in, &fmt_out, &GST_OSX_AAC_ENCODE(enc)->encoder);
	
	AudioConverterSetProperty(GST_OSX_AAC_ENCODE(enc)->encoder, kAudioConverterEncodeBitRate, sizeof(GST_OSX_AAC_ENCODE(enc)->bitrate), &GST_OSX_AAC_ENCODE(enc)->bitrate);
	AudioConverterGetProperty(GST_OSX_AAC_ENCODE(enc)->encoder, kAudioConverterCompressionMagicCookie, &tmp, data);
	
	ReadESDSDescExt(data, &buffer, &tmp, 0);
	
	codec_data = gst_buffer_new_and_alloc(tmp);
	gst_buffer_fill(codec_data, 0, buffer, tmp);
	free(buffer);
	
	gst_caps_set_simple(caps, "codec_data", GST_TYPE_BUFFER, codec_data, NULL);
	gst_buffer_unref(codec_data);
	
	gst_audio_encoder_set_output_format(enc, caps);
	gst_caps_unref(caps);
	
	return TRUE;
}

static gboolean gst_osx_aac_encode_stop(GstAudioEncoder *enc)
{
	if (GST_OSX_AAC_ENCODE(enc)->encoder)
	{
		AudioConverterDispose(GST_OSX_AAC_ENCODE(enc)->encoder);
	}
	
	return TRUE;
}

static OSStatus aac_cb(AudioConverterRef encoder, UInt32 *num, AudioBufferList *list, AudioStreamPacketDescription **desc, void *user)
{
	GstMapInfo *info = user;
	
	list->mBuffers[0].mNumberChannels = 2;
	list->mBuffers[0].mDataByteSize = info->size;
	list->mBuffers[0].mData = info->data;
	
	return noErr;
}

static GstFlowReturn gst_osx_aac_encode_handle_frame(GstAudioEncoder *enc, GstBuffer *buf)
{
	GstMapInfo info_in;
	GstMapInfo info_out;
	GstBuffer *buf_out;
	UInt32 desc_num = 1;
	UInt32 max_out_buf;
	UInt32 max_out_buf_size = sizeof(max_out_buf);
	OSStatus err;
	
	if (!buf)
	{
		return GST_FLOW_OK;
	}
	
	AudioConverterGetProperty(GST_OSX_AAC_ENCODE(enc)->encoder, kAudioConverterPropertyMaximumOutputPacketSize, &max_out_buf_size, &max_out_buf);
	
	buf_out = gst_buffer_new_allocate(NULL, max_out_buf, NULL);
	
	gst_buffer_map(buf, &info_in, GST_MAP_READ);
	gst_buffer_map(buf_out, &info_out, GST_MAP_WRITE);
	
	AudioBufferList list =
	{
		.mNumberBuffers = 1,
		.mBuffers =
		{
			{
				.mNumberChannels = 2,
				.mDataByteSize = info_out.size,
				.mData = info_out.data,
			},
		},
	};
	
	err = AudioConverterFillComplexBuffer(GST_OSX_AAC_ENCODE(enc)->encoder, aac_cb, &info_in, &desc_num, &list, NULL);
	
	gst_buffer_unmap(buf, &info_in);
	gst_buffer_unmap(buf_out, &info_out);
	
	if (err != noErr)
	{
		gst_buffer_unref(buf_out);
		
		return GST_FLOW_OK;
	}
	
	gst_buffer_set_size(buf_out, list.mBuffers[0].mDataByteSize);
	
	return gst_audio_encoder_finish_frame(enc, buf_out, 1024);
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
	
	GST_AUDIO_ENCODER_CLASS(class)->handle_frame = gst_osx_aac_encode_handle_frame;
	GST_AUDIO_ENCODER_CLASS(class)->set_format = gst_osx_aac_encode_set_format;
	GST_AUDIO_ENCODER_CLASS(class)->stop = gst_osx_aac_encode_stop;
	
	G_OBJECT_CLASS(class)->set_property = gst_osx_aac_encode_set_property;
	G_OBJECT_CLASS(class)->get_property = gst_osx_aac_encode_get_property;
	
	g_object_class_install_property(G_OBJECT_CLASS(class), PROP_BITRATE, g_param_spec_int("bitrate", "Bitrate (bps)", "Average Bitrate (ABR) in bits/sec", 64000, 320000, 128000, G_PARAM_CONSTRUCT | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS));
}

static void gst_osx_aac_encode_init(GstOsxAacEncode *filter)
{
	gst_audio_encoder_set_frame_samples_min(GST_AUDIO_ENCODER(filter), 1024);
	gst_audio_encoder_set_frame_samples_max(GST_AUDIO_ENCODER(filter), 1024);
	
	filter->encoder = NULL;
	filter->bitrate = 128000;
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
	"0.1.8",
	"GPL",
	"Mincer",
	"https://github.com/fzwoch/mincer/"
)
