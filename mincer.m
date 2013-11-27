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

#define MAX_AUDIO_DEVICES 32

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
	
	{0, 0, ""},
	
	{640, 400, "16:10"},
	{800, 500, "16:10"},
	{960, 600, "16:10"},
	{1024, 640, "16:10"},
	{1152, 720, "16:10"},
	{1280, 800, "16:10"},
	{1440, 900, "16:10"},
	{1680, 1050, "16:10"},
	{1920, 1200, "16:10"},
	
	{0, 0, ""},
	
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

static gchar *encoder_speeds[] =
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

static gint audio_bitrates[] =
{
	64,
	72,
	80,
	96,
	112,
	128,
	144,
	160,
	192,
	224,
	256,
	288,
	320
};

static glong audio_device_ids[MAX_AUDIO_DEVICES] = {0};
static glong audio_soundflower_id = 0;

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
	
	NSTextField *encoder_speed_label;
	NSSlider *encoder_speed;
	
	NSTextField *video_bitrate_label;
	NSSlider *video_bitrate;
	
	NSPopUpButton *audio_device;
	
	NSTextField *audio_bitrate_label;
	NSSlider *audio_bitrate;
	
	NSOpenPanel *mp4_recording_panel;
	NSButton *mp4_recording;
	NSInteger mp4_recording_enabled;
	
	NSButton *button;
	
	NSDate *start_date;
	NSTimer *timer;
	NSTextField *elapsed_time;
	
	GstElement *pipeline;
}
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[NSApp setMainMenu:[NSMenu new]];
	
	NSMenuItem *item = [[NSApp mainMenu] addItemWithTitle:@"Mincer" action:nil keyEquivalent:@""];
	
	NSMenu *mincer_menu = [NSMenu new];
	[mincer_menu setTitle:@"Mincer"];
	[mincer_menu addItemWithTitle:@"About Mincer" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
	[mincer_menu addItem:[NSMenuItem separatorItem]];
	[mincer_menu addItemWithTitle:@"Preferences" action:nil keyEquivalent:@","];
	[mincer_menu addItem:[NSMenuItem separatorItem]];
	[mincer_menu addItemWithTitle:@"Hide Mincer" action:@selector(hide:) keyEquivalent:@"h"];
	[[mincer_menu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"] setKeyEquivalentModifierMask:NSAlternateKeyMask | NSCommandKeyMask];
	[mincer_menu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
	[mincer_menu addItem:[NSMenuItem separatorItem]];
	[mincer_menu addItemWithTitle:@"Quit Mincer" action:@selector(terminate:) keyEquivalent:@"q"];
	[item setSubmenu:mincer_menu];
	
	item = [[NSApp mainMenu] addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
	
	NSMenu *edit_menu = [NSMenu new];
	[edit_menu setTitle:@"Edit"];
	[edit_menu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
	[[edit_menu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"] setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
	[edit_menu addItem:[NSMenuItem separatorItem]];
	[edit_menu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
	[edit_menu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
	[edit_menu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
	[edit_menu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%c", NSBackspaceCharacter ]];
	[edit_menu addItem:[NSMenuItem separatorItem]];
	[edit_menu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
	[item setSubmenu:edit_menu];
	
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
	[url setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	url_secret = [NSSecureTextField new];
	[url_secret setHidden:YES];
	[url_secret setEnabled:NO];
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
		if (resolutions[i].width == 0)
		{
			[[resolution menu] addItem:[NSMenuItem separatorItem]];
		}
		else
		{
			[resolution addItemWithTitle:[NSString stringWithFormat:@"%dx%d\t%s", resolutions[i].width, resolutions[i].height, resolutions[i].aspect_ratio]];
		}
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
	
	encoder_speed_label = [NSTextField new];
	[encoder_speed_label setBezeled:NO];
	[encoder_speed_label setDrawsBackground:NO];
	[encoder_speed_label setEditable:NO];
	[encoder_speed_label setSelectable:NO];
	[encoder_speed_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	encoder_speed = [NSSlider new];
	[encoder_speed setMinValue:1];
	[encoder_speed setMaxValue:10];
	[encoder_speed setNumberOfTickMarks:[encoder_speed maxValue]];
	[encoder_speed setAllowsTickMarkValuesOnly:YES];
	[encoder_speed setTranslatesAutoresizingMaskIntoConstraints:NO];
	[encoder_speed setAction:@selector(updateEncoderSpeed)];
	
	video_bitrate_label = [NSTextField new];
	[video_bitrate_label setBezeled:NO];
	[video_bitrate_label setDrawsBackground:NO];
	[video_bitrate_label setEditable:NO];
	[video_bitrate_label setSelectable:NO];
	[video_bitrate_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	video_bitrate = [NSSlider new];
	[video_bitrate setMinValue:300];
	[video_bitrate setMaxValue:3000];
	[video_bitrate setNumberOfTickMarks:([video_bitrate maxValue] - [video_bitrate minValue]) / 50 + 1];
	[video_bitrate setAllowsTickMarkValuesOnly:YES];
	[video_bitrate setTranslatesAutoresizingMaskIntoConstraints:NO];
	[video_bitrate setAction:@selector(updateVideoBitrate)];
	
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
	glong *audio_device_id = audio_device_ids;
	
	audio_device_id[0] = 0;
	audio_device_id++;
	
	AudioObjectPropertyAddress addr =
	{
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size);
	AudioDeviceID *devices = malloc(size);
	AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devices);
	
	gint device_count = size / sizeof(AudioDeviceID);
	
	if (device_count > MAX_AUDIO_DEVICES - 1)
	{
		device_count = MAX_AUDIO_DEVICES - 1;
	}
	
	for (gint i = 0; i < device_count; i++)
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
			[audio_device addItemWithTitle:(NSString*)name];
			
			audio_device_id[0] = devices[i];
			audio_device_id++;
			
			if ([(NSString*)name isEqualToString:@"Soundflower (2ch)"])
			{
				audio_soundflower_id = devices[i];
			}
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
	[audio_bitrate setMinValue:0];
	[audio_bitrate setMaxValue:sizeof(audio_bitrates) / sizeof(audio_bitrates[0]) - 1];
	[audio_bitrate setNumberOfTickMarks:sizeof(audio_bitrates) / sizeof(audio_bitrates[0])];
	[audio_bitrate setAllowsTickMarkValuesOnly:YES];
	[audio_bitrate setTranslatesAutoresizingMaskIntoConstraints:NO];
	[audio_bitrate setAction:@selector(updateAudioBitrate)];
	
	mp4_recording_panel = [NSOpenPanel new];
	[mp4_recording_panel setCanChooseFiles:NO];
	[mp4_recording_panel setCanChooseDirectories:YES];
	[mp4_recording_panel setAllowsMultipleSelection:NO];
	
	NSTextField *mp4_recording_label = [NSTextField new];
	[mp4_recording_label setStringValue:@"Recordings"];
	[mp4_recording_label setBezeled:NO];
	[mp4_recording_label setDrawsBackground:NO];
	[mp4_recording_label setEditable:NO];
	[mp4_recording_label setSelectable:NO];
	[mp4_recording_label setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	mp4_recording = [NSButton new];
	[mp4_recording setBezelStyle:NSRoundedBezelStyle];
	[mp4_recording setTranslatesAutoresizingMaskIntoConstraints:NO];
	[mp4_recording setAction:@selector(chooseRecordingDirectory)];
	
	elapsed_time = [NSTextField new];
	[elapsed_time setTextColor:[NSColor grayColor]];
	[elapsed_time setBezeled:NO];
	[elapsed_time setDrawsBackground:NO];
	[elapsed_time setEditable:NO];
	[elapsed_time setSelectable:NO];
	[elapsed_time setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	start_date = NULL;
	timer = NULL;
	
	[self updateElapsedTime];
	
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
	[[window contentView] addSubview:encoder_speed_label];
	[[window contentView] addSubview:encoder_speed];
	[[window contentView] addSubview:video_bitrate_label];
	[[window contentView] addSubview:video_bitrate];
	[[window contentView] addSubview:audio_device_label];
	[[window contentView] addSubview:audio_device];
	[[window contentView] addSubview:audio_bitrate_label];
	[[window contentView] addSubview:audio_bitrate];
	[[window contentView] addSubview:mp4_recording_label];
	[[window contentView] addSubview:mp4_recording];
	[[window contentView] addSubview:elapsed_time];
	[[window contentView] addSubview:button];
	
	NSDictionary *views = NSDictionaryOfVariableBindings(url_label, url, url_secret, resolution_label, resolution, framerate_label, framerate, encoder_speed_label, encoder_speed, video_bitrate_label, video_bitrate, audio_device_label, audio_device, audio_bitrate_label, audio_bitrate, mp4_recording_label, mp4_recording, elapsed_time, button);
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[url_secret]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[url_label]-[url_secret]" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[resolution_label]-15-[framerate_label(==resolution_label)]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[resolution]-15-[framerate(==resolution)]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[url]-15-[framerate_label]-[framerate]" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[encoder_speed_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[encoder_speed]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[video_bitrate_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[video_bitrate]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_device_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_device]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_bitrate_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[audio_bitrate]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[mp4_recording_label]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[mp4_recording(==330)]-15-|" options:0 metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[elapsed_time]" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[elapsed_time]-[button]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
	
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[button(==100)]-15-|" options:0 metrics:nil views:views]];
	[[window contentView] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[url_label]-[url]-15-[resolution_label]-[resolution]-15-[encoder_speed_label]-[encoder_speed(>=25)]-15-[video_bitrate_label]-[video_bitrate(>=25)]-15-[audio_device_label]-[audio_device]-15-[audio_bitrate_label]-[audio_bitrate(>=25)]-15-[mp4_recording_label]-[mp4_recording]-[button]-15-|" options:0 metrics:nil views:views]];
	
	[window setDelegate:[NSApp delegate]];
	[window makeKeyAndOrderFront:nil];
	
	if ([NSEvent modifierFlags] & NSCommandKeyMask)
	{
		[url setStringValue:@"rtmp://live.twitch.tv/app/"];
		[resolution selectItemAtIndex:0];
		[framerate selectItemAtIndex:0];
		[encoder_speed setIntValue:[encoder_speed minValue]];
		[video_bitrate setIntValue:[video_bitrate minValue]];
		[audio_device selectItemAtIndex:0];
		[audio_bitrate setIntValue:[audio_bitrate minValue]];
		[mp4_recording_panel setDirectoryURL:[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0]];
		mp4_recording_enabled = 0;
		
		[window center];
	}
	else
	{
		NSPoint point;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		[url setStringValue:[defaults stringForKey:@"url"] ? [defaults stringForKey:@"url"] : @"rtmp://live.twitch.tv/app/"];
		[resolution selectItemAtIndex:[defaults integerForKey:@"resolution"]];
		[framerate selectItemAtIndex:[defaults integerForKey:@"framerate"]];
		[encoder_speed setIntValue:[defaults integerForKey:@"encoder_speed"] ? [defaults integerForKey:@"encoder_speed"] : [encoder_speed minValue]];
		[video_bitrate setIntValue:[defaults integerForKey:@"video_bitrate"] ? [defaults integerForKey:@"video_bitrate"] : [video_bitrate minValue]];
		[audio_device selectItemWithTitle:[defaults stringForKey:@"audio_device"] ? [defaults stringForKey:@"audio_device"] : [audio_device itemTitleAtIndex:0]];
		[audio_bitrate setIntValue:[defaults integerForKey:@"audio_bitrate"] ? [defaults integerForKey:@"audio_bitrate"] : [audio_bitrate minValue]];
		[mp4_recording_panel setDirectoryURL:[defaults URLForKey:@"mp4_recording_panel"] ? [defaults URLForKey:@"mp4_recording_panel"] : [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0]];
		mp4_recording_enabled = [defaults integerForKey:@"mp4_recording_enabled"];
		
		point.x = [defaults floatForKey:@"pos_x"];
		point.y = [defaults floatForKey:@"pos_y"];
		
		if (point.x || point.y)
		{
			[window setFrameOrigin:point];
		}
		else
		{
			[window center];
		}
	}
	
	[self updateEncoderSpeed];
	[self updateVideoBitrate];
	[self updateAudioBitrate];
	[self updateRecordingDirectory];
	
	if ([audio_device indexOfSelectedItem] == -1)
	{
		[audio_device selectItemAtIndex:0];
	}
	
	pipeline = NULL;
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (pipeline)
	{
		[self stopStream];
	}
	
//	gst_deinit();
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:[url stringValue] forKey:@"url"];
	[defaults setInteger:[resolution indexOfSelectedItem] forKey:@"resolution"];
	[defaults setInteger:[framerate indexOfSelectedItem] forKey:@"framerate"];
	[defaults setInteger:[encoder_speed integerValue] forKey:@"encoder_speed"];
	[defaults setInteger:[video_bitrate integerValue] forKey:@"video_bitrate"];
	[defaults setObject:[audio_device titleOfSelectedItem] forKey:@"audio_device"];
	[defaults setInteger:[audio_bitrate integerValue] forKey:@"audio_bitrate"];
	[defaults setURL:[mp4_recording_panel directoryURL] forKey:@"mp4_recording_panel"];
	[defaults setInteger:mp4_recording_enabled forKey:@"mp4_recording_enabled"];
	[defaults synchronize];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}
- (void)windowWillClose:(NSNotification *)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setFloat:[[NSApp keyWindow] frame].origin.x forKey:@"pos_x"];
	[defaults setFloat:[[NSApp keyWindow] frame].origin.y forKey:@"pos_y"];
}
- (void)toggleStream
{
	pipeline ? [self stopStream] : [self startStream];
}
- (void)startStream
{
	GError *error = NULL;
	GstBus *bus;
	
	if (![[url stringValue] length] && !mp4_recording_enabled)
	{
		[self alert:@"No RTMP and no MP4 option set. Nothing to be done."];
		
		return;
	}
	
	NSDateFormatter* date = [NSDateFormatter new];
	[date setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
	
	NSMutableString *desc = [NSMutableString new];
	
	[desc appendFormat:@"osxdesktopsrc ! video/x-raw, framerate=%d/1 ! queue ! osxvideoscale ! video/x-raw, width=%d, height=%d ! ", framerates[[framerate indexOfSelectedItem]], resolutions[[resolution indexOfSelectedItem]].width, resolutions[[resolution indexOfSelectedItem]].height];
	[desc appendFormat:@"videoconvert ! video/x-raw, format=I420 ! x264enc bitrate=%d speed-preset=%d bframes=0 key-int-max=%d ! h264parse ! tee name=tee_264 ", [video_bitrate intValue], [encoder_speed intValue], framerates[[framerate indexOfSelectedItem]] * 2];
	[desc appendFormat:@"adder name=audio_mix ! osxaacencode bitrate=%d ! aacparse ! tee name=tee_aac ", audio_bitrates[[audio_bitrate intValue]] * 1000];
	
	if (audio_soundflower_id)
	{
		[desc appendFormat:@"osxaudiosrc device=%ld ! audioconvert ! audioresample ! audio_mix. ", audio_soundflower_id];
	}
	
	if ([audio_device indexOfSelectedItem])
	{
		[desc appendFormat:@"osxaudiosrc device=%ld ! audioconvert ! audioresample ! audio_mix. ", audio_device_ids[[audio_device indexOfSelectedItem]]];
	}
	
	if (![audio_device indexOfSelectedItem] && !audio_soundflower_id)
	{
		[desc appendFormat:@"audiotestsrc is-live=true wave=silence ! audio_mix. "];
	}
	
	if ([[url stringValue] length])
	{
		[desc appendFormat:@"tee_aac. ! queue max-size-time=0 ! flv_mux. "];
		[desc appendFormat:@"tee_264. ! queue ! flvmux streamable=true name=flv_mux ! rtmpsink location=\"%@\" ", [[url stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	
	if (mp4_recording_enabled)
	{
		[desc appendFormat:@"tee_aac. ! queue max-size-time=0 ! mp4_mux. "];
		[desc appendFormat:@"tee_264. ! queue ! mp4mux name=mp4_mux ! filesink location=\"%@/mincer_%@.mp4\" ", [[mp4_recording_panel directoryURL] relativePath], [date stringFromDate:[NSDate date]]];
	}
	
	pipeline = gst_parse_launch([desc cStringUsingEncoding:NSUTF8StringEncoding], &error);
	if (error)
	{
		[self alert:[NSString stringWithCString:error->message encoding:NSUTF8StringEncoding]];
		g_error_free(error);
		
		if (pipeline)
		{
			gst_object_unref(pipeline);
			pipeline = NULL;
		}
		
		return;
	}
	
	[date release];
	[desc release];
	
	bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
	gst_bus_set_sync_handler(bus, bus_call, NULL, NULL);
	gst_object_unref(bus);
	
	[url_secret setStringValue:[url stringValue]];
	[url_secret setHidden:NO];
	[url setHidden:YES];
	
	[[[NSApp keyWindow] contentView] display];
	
	[url setEnabled:NO];
	[resolution setEnabled:NO];
	[framerate setEnabled:NO];
	[encoder_speed setEnabled:NO];
	[video_bitrate setEnabled:NO];
	[audio_device setEnabled:NO];
	[audio_bitrate setEnabled:NO];
	[mp4_recording setEnabled:NO];
	
	gst_element_set_state(pipeline, GST_STATE_PLAYING);
	gst_element_get_state(pipeline, NULL, NULL, GST_CLOCK_TIME_NONE);
	
	start_date = [NSDate new];
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateElapsedTime) userInfo:nil repeats:YES];
	
	[timer fire];
	
	[button setTitle:@"Stop"];
}
- (void)stopStream
{
	GstStateChangeReturn change;
	GstBus *bus;
	
	if (!pipeline)
	{
		return;
	}
	
	bus = gst_element_get_bus(pipeline);
	
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
	
	[url setEnabled:YES];
	[resolution setEnabled:YES];
	[framerate setEnabled:YES];
	[encoder_speed setEnabled:YES];
	[video_bitrate setEnabled:YES];
	[audio_device setEnabled:YES];
	[audio_bitrate setEnabled:YES];
	[mp4_recording setEnabled:YES];
	
	if (start_date)
	{
		[start_date release];
		start_date = NULL;
	}
	
	if (timer)
	{
		[timer invalidate];
		timer = NULL;
	}
	
	[self updateElapsedTime];
	
	[button setTitle:@"Start"];
}
- (void)updateEncoderSpeed
{	
	[encoder_speed_label setStringValue:[NSString stringWithFormat:@"Video Encoder Speed - %s", encoder_speeds[[encoder_speed intValue]]]];
}
- (void)updateVideoBitrate
{
	[video_bitrate_label setStringValue:[NSString stringWithFormat:@"Video Bitrate - %d kbps", [video_bitrate intValue]]];
}
- (void)updateAudioBitrate
{
	[audio_bitrate_label setStringValue:[NSString stringWithFormat:@"Audio Bitrate - %d kbps", audio_bitrates[[audio_bitrate intValue]]]];
}
- (void)updateRecordingDirectory
{
	[mp4_recording setTitle: mp4_recording_enabled ? [[mp4_recording_panel directoryURL] relativePath] : @"- Disabled -"];
}
- (void)chooseRecordingDirectory
{
	mp4_recording_enabled = [mp4_recording_panel runModal];
	
	[self updateRecordingDirectory];
}
- (void)updateElapsedTime
{
	if (!timer)
	{
		[elapsed_time setStringValue:@"--:--:--"];
		
		return;
	}
	
	NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start_date];
	NSDate *time = [NSDate dateWithTimeIntervalSince1970:elapsed];
	NSDateFormatter *date = [NSDateFormatter new];
	
	[date setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
	[date setDateFormat:@"HH:mm:ss"];
	
	[elapsed_time setStringValue:[date stringFromDate:time]];
	
	[date release];
}
- (void)alert:(NSString *)message
{
	[[NSAlert alertWithMessageText:@"Mincer error" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", message] runModal];
}
@end

int main(int argc, char *argv[])
{
	g_setenv("LC_ALL", "en_US.UTF-8", TRUE);
	
	gst_init(&argc, &argv);
	gst_registry_fork_set_enabled(FALSE);
	gst_registry_scan_path(gst_registry_get(), [[[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingString:@"/gstreamer-1.0/"] cStringUsingEncoding:NSUTF8StringEncoding]);
	
	[NSApplication sharedApplication];
	[NSApp setDelegate:[AppDelegate new]];
	[NSApp run];
	
	return 0;
}
