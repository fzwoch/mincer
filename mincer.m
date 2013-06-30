/*
 * mincer
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

#import <Cocoa/Cocoa.h>
#import <CoreAudio/AudioHardware.h>
#import <gst/gst.h>

struct resolution_pair {
	gint width;
	gint height;
	gchar aspect_ratio[64];
};

static struct resolution_pair resolutions[] =
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

static gint framerates[] =
{
	5,
	10,
	15,
	20,
	25,
	30,
	35,
	40,
	45,
	50,
	55,
	60
};

static GstBusSyncReply bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
	gchar *debug;
	GError *error;
	
	switch (GST_MESSAGE_TYPE(msg))
	{
	case GST_MESSAGE_WARNING:
		@autoreleasepool
		{
			gst_message_parse_warning(msg, &error, &debug);
			g_free(debug);
		
			NSLog(@"%@", [NSString stringWithCString:error->message encoding:NSUTF8StringEncoding]);
			g_error_free(error);
		}
		break;
	case GST_MESSAGE_ERROR:
		@autoreleasepool
		{
			gst_message_parse_error(msg, &error, &debug);
			g_free(debug);

			[[NSApp delegate] performSelectorOnMainThread:@selector(alert:) withObject:[NSString stringWithCString:error->message encoding:NSUTF8StringEncoding] waitUntilDone:YES];
			g_error_free(error);
		
			[[NSApp delegate] performSelectorOnMainThread:@selector(stopStream) withObject:nil waitUntilDone:NO];
		}
		break;
	default:
		break;
	}
	
	return GST_BUS_DROP;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	NSTextField *url;
	NSSecureTextField *url_secret;
	
	NSPopUpButton *resolution;
	NSPopUpButton *framerate;
	
	NSTextField *video_bitrate_label;
	NSSlider *video_bitrate;
	
	NSPopUpButton *audio_device;
	
	NSTextField *audio_bitrate_label;
	NSSlider *audio_bitrate;
	
	NSProgressIndicator *progress;
	NSButton *button;
	
	GstElement *pipeline;
}
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSWindow *window = [NSWindow new];
	[window setStyleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask];
	[window setBackingType:NSBackingStoreBuffered];
	[window setTitle:@"Mincer"];
	
	NSTextField *url_label = [NSTextField new];
	[url_label setStringValue:@"RTMP Streaming URL"];
	[url_label setBezeled:NO];
	[url_label setDrawsBackground:NO];
	[url_label setEditable:NO];
	[url_label setSelectable:NO];
	[url_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	url = [NSTextField new];
	[url setStringValue:@"rtmp://live.twitch.tv/app/"];
	[url setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	url_secret = [NSSecureTextField new];
	[url_secret setHidden:YES];
	[url_secret setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	[[url cell] setLineBreakMode:NSLineBreakByCharWrapping];
	[[url_secret cell] setLineBreakMode:NSLineBreakByCharWrapping];
	
	NSTextField *resolution_label = [NSTextField new];
	[resolution_label setStringValue:@"Video Resolution"];
	[resolution_label setBezeled:NO];
	[resolution_label setDrawsBackground:NO];
	[resolution_label setEditable:NO];
	[resolution_label setSelectable:NO];
	[resolution_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	resolution = [NSPopUpButton new];
	[resolution setPullsDown:NO];
	[resolution setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	for (gint i = 0; i < sizeof(resolutions) / sizeof(struct resolution_pair); i++)
	{
		[resolution addItemWithTitle:[NSString stringWithFormat:@"%dx%d\t%s", resolutions[i].width, resolutions[i].height, resolutions[i].aspect_ratio]];
	}
	
	NSTextField *framerate_label = [NSTextField new];
	[framerate_label setStringValue:@"Framerate"];
	[framerate_label setBezeled:NO];
	[framerate_label setDrawsBackground:NO];
	[framerate_label setEditable:NO];
	[framerate_label setSelectable:NO];
	[framerate_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	framerate = [NSPopUpButton new];
	[framerate setPullsDown:NO];
	[framerate setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	for (gint i = 0; i < sizeof(framerates) / sizeof(gint); i++)
	{
		[framerate addItemWithTitle:[NSString stringWithFormat:@"%d", framerates[i]]];
	}
	
	[framerate selectItemWithTitle:@"30"];
	
	video_bitrate_label = [NSTextField new];
	[video_bitrate_label setBezeled:NO];
	[video_bitrate_label setDrawsBackground:NO];
	[video_bitrate_label setEditable:NO];
	[video_bitrate_label setSelectable:NO];
	[video_bitrate_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	video_bitrate = [NSSlider new];
	[video_bitrate setMinValue:300];
	[video_bitrate setMaxValue:3000];
	[video_bitrate setIntValue:800];
	[video_bitrate setNumberOfTickMarks:([video_bitrate maxValue] - [video_bitrate minValue]) / 50 + 1];
	[video_bitrate setAllowsTickMarkValuesOnly:YES];
	[video_bitrate setTranslatesAutoresizingMaskIntoConstraints:NO];
	[video_bitrate setAction:@selector(updateVideoBitrate)];
	
	[self updateVideoBitrate];
	
	NSTextField *audio_device_label = [NSTextField new];
	[audio_device_label setStringValue:@"Audio Input"];
	[audio_device_label setBezeled:NO];
	[audio_device_label setDrawsBackground:NO];
	[audio_device_label setEditable:NO];
	[audio_device_label setSelectable:NO];
	[audio_device_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	audio_device = [NSPopUpButton new];
	[audio_device setPullsDown:NO];
	[audio_device setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	[audio_device addItemWithTitle:[NSString stringWithFormat:@"None"]];
	
	guint size = 0;
	
	AudioObjectPropertyAddress addr =
	{
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size);
	AudioDeviceID *devices = malloc(size);
	AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);
	
	for (gint i = 0; i < size / sizeof(AudioDeviceID); i++)
	{
		CFStringRef name = NULL;
		
		addr.mSelector = kAudioDevicePropertyDeviceNameCFString;
		addr.mScope = kAudioObjectPropertyScopeGlobal;
		
		AudioObjectGetPropertyData(devices[i], &addr, 0, NULL, &size, &name);
			
		addr.mSelector = kAudioDevicePropertyStreams;
		addr.mScope = kAudioDevicePropertyScopeInput;
		
		AudioObjectGetPropertyDataSize(devices[i], &addr, 0, NULL, &size);
		
		if (size)
		{
			[audio_device addItemWithTitle:(NSString*)name];
		}
		
		CFRelease(name);
	}
	
	if (devices)
	{
		free(devices);
	}
	
	audio_bitrate_label = [NSTextField new];
	[audio_bitrate_label setBezeled:NO];
	[audio_bitrate_label setDrawsBackground:NO];
	[audio_bitrate_label setEditable:NO];
	[audio_bitrate_label setSelectable:NO];
	[audio_bitrate_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	audio_bitrate = [NSSlider new];
	[audio_bitrate setMinValue:32];
	[audio_bitrate setMaxValue:320];
	[audio_bitrate setIntValue:128];
	[audio_bitrate setNumberOfTickMarks:([audio_bitrate maxValue] - [audio_bitrate minValue]) / 16 + 1];
	[audio_bitrate setAllowsTickMarkValuesOnly:YES];
	[audio_bitrate setTranslatesAutoresizingMaskIntoConstraints:NO];
	[audio_bitrate setAction:@selector(updateAudioBitrate)];
	
	[self updateAudioBitrate];
	
	progress = [NSProgressIndicator new];
	[progress setStyle:NSProgressIndicatorSpinningStyle];
	[progress setControlSize:NSSmallControlSize];
	[progress setIndeterminate:YES];
	[progress setHidden:YES];
	[progress setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	button = [NSButton new];
	[button setTitle:@"Start"];
	[button setBezelStyle:NSRoundedBezelStyle];
	[button setAction:@selector(toggleStream)];
	[button setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	[[window contentView] addSubview:url_label];
	[[window contentView] addSubview:url];
	[[window contentView] addSubview:url_secret];
	[[window contentView] addSubview:resolution_label];
	[[window contentView] addSubview:resolution];
	[[window contentView] addSubview:framerate_label];
	[[window contentView] addSubview:framerate];
	[[window contentView] addSubview:video_bitrate_label];
	[[window contentView] addSubview:video_bitrate];
	[[window contentView] addSubview:audio_device_label];
	[[window contentView] addSubview:audio_device];
	[[window contentView] addSubview:audio_bitrate_label];
	[[window contentView] addSubview:audio_bitrate];
	[[window contentView] addSubview:progress];
	[[window contentView] addSubview:button];
	
	NSDictionary *views = NSDictionaryOfVariableBindings(url_label, url, url_secret, resolution_label, resolution, framerate_label, framerate, video_bitrate_label, video_bitrate, audio_device_label, audio_device, audio_bitrate_label, audio_bitrate, progress, button);
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url(>=300)]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url_secret]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[url_label]-[url_secret]" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[resolution_label]-15-[framerate_label(==resolution_label)]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[resolution]-15-[framerate(==resolution)]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[url]-15-[framerate_label]-[framerate]" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[video_bitrate_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[video_bitrate]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_device_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_device]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_bitrate_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_bitrate]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[progress]" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[progress]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[button(==100)]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[url_label]-[url]-15-[resolution_label]-[resolution]-15-[video_bitrate_label]-[video_bitrate(>=25)]-15-[audio_device_label]-[audio_device]-15-[audio_bitrate_label]-[audio_bitrate(>=25)]-[button]-15-|" options:0 metrics:nil views:views]];
	
	[window makeKeyAndOrderFront:nil];
	[window center];
	
	pipeline = NULL;
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (pipeline)
	{
		[self stopStream];
	}
	
	gst_deinit();
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}
- (void)toggleStream
{
	pipeline ? [self stopStream] : [self startStream];
}
- (void)startStream
{
	GError *error = NULL;
	GstBus *bus;
	
	NSDateFormatter* date = [NSDateFormatter new];
	[date setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
	
	NSString *desc = [NSString stringWithFormat:@
		"osxdesktopsrc ! video/x-raw, framerate=%d/1 ! videoscale ! video/x-raw, width=%d, height=%d ! tee name=tee_vid "
		"tee_vid. ! queue ! videoconvert ! x264enc bitrate=%d speed-preset=1 ! tee name=tee_264 "
		"tee_264. ! queue ! flvmux name=flv_mux ! %@=\"%@\" "
		"tee_264. ! queue ! qtmux name=mp4_mux ! filesink location=\"%@/mincer_%@.mp4\" "
		"osxaudiosrc do-timestamp=true ! audioconvert ! faac bitrate=%d ! audio/mpeg, mpegversion=4 ! tee name=tee_aac "
		"tee_aac. ! queue max-size-time=0 ! flv_mux. "
		"tee_aac. ! queue max-size-time=0 ! mp4_mux.",
		framerates[[framerate indexOfSelectedItem]],
		resolutions[[resolution indexOfSelectedItem]].width,
		resolutions[[resolution indexOfSelectedItem]].height,
		[video_bitrate intValue],
		[[url stringValue] length] == 0 ? @"fakesink name" : @"rtmpsink location",
		[[url stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
		[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0],
		[date stringFromDate:[NSDate date]],
		[audio_bitrate intValue] * 1000];
	
	pipeline = gst_parse_launch([desc cStringUsingEncoding:NSUTF8StringEncoding], &error);
	if (error)
	{
		[self alert:[NSString stringWithCString:error->message encoding:NSUTF8StringEncoding]];
		
		g_error_free(error);
		
		return;
	}
	
	bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
	gst_bus_set_sync_handler(bus, bus_call, NULL, NULL);
	gst_object_unref(bus);
	
	[url_secret setStringValue:[url stringValue]];
	[url_secret setHidden:NO];
	[url setHidden:YES];
	
	[[[NSApp keyWindow] contentView] display];
	
	gst_element_set_state(pipeline, GST_STATE_PLAYING);
	gst_element_get_state(pipeline, NULL, NULL, GST_CLOCK_TIME_NONE);
	
	[progress startAnimation:nil];
	[progress setHidden:NO];
	
	[button setTitle:@"Stop"];
}
- (void)stopStream
{
	GstStateChangeReturn change;
	GstBus *bus = gst_element_get_bus(pipeline);
	
	gst_bus_set_sync_handler(bus, NULL, NULL, NULL);
	
	change = gst_element_get_state(pipeline, NULL, NULL, GST_CLOCK_TIME_NONE);
	if (change == GST_STATE_CHANGE_SUCCESS)
	{
		gst_element_send_event(pipeline, gst_event_new_eos());
		gst_bus_poll(bus, GST_MESSAGE_EOS, GST_CLOCK_TIME_NONE);
		
		gst_element_set_state(pipeline, GST_STATE_NULL);
		gst_element_get_state(pipeline, NULL, NULL, GST_CLOCK_TIME_NONE);
	}
	
	gst_object_unref(pipeline);
	pipeline = NULL;
	
	[url setStringValue:[url_secret stringValue]];
	[url setHidden:NO];
	[url_secret setHidden:YES];
	
	[progress setHidden:YES];
	[progress stopAnimation:nil];
	
	[button setTitle:@"Start"];
}
- (void)updateVideoBitrate
{
	[video_bitrate_label setStringValue:[NSString stringWithFormat:@"Video Bitrate - %d kbps", [video_bitrate intValue]]];
}
- (void)updateAudioBitrate
{
	[audio_bitrate_label setStringValue:[NSString stringWithFormat:@"Audio Bitrate - %d kbps", [audio_bitrate intValue]]];
}
- (void)alert:(NSString *)message
{
	[[NSAlert alertWithMessageText:@"Mincer error" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", message] runModal];
}
@end

int main(int argc, char *argv[])
{
	gst_registry_fork_set_enabled(FALSE);
	gst_init(&argc, &argv);
	gst_registry_scan_path(gst_registry_get(), [[[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingString:@"/gstreamer-1.0/"] cStringUsingEncoding:NSUTF8StringEncoding]);
	
	[NSApplication sharedApplication];
	[NSApp setDelegate:[AppDelegate new]];
	[NSApp run];
	
	return 0;
}