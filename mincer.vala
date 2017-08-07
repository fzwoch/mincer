using Gtk;
using Gst;

class Mincer : Gtk.Application {
	Pipeline pipeline = null;

	public override void activate () {
		var builder = new Builder.from_file ("/usr/local/share/mincer/mincer.glade");

		var window = builder.get_object ("window") as ApplicationWindow;
		var url = builder.get_object ("url") as Entry;
		var video_input = builder.get_object ("video_input") as ComboBoxText;
		var video_resolution = builder.get_object ("video_resolution") as ComboBoxText;
		var video_framerate = builder.get_object ("video_framerate") as ComboBoxText;
		var video_speed = builder.get_object ("video_speed") as Scale;
		var video_bitrate = builder.get_object ("video_bitrate") as Scale;
		var audio_input = builder.get_object ("audio_input") as ComboBoxText;
		var audio_mute = builder.get_object ("audio_mute") as ToggleButton;
		var audio_bitrate = builder.get_object ("audio_bitrate") as Scale;
		var recordings = builder.get_object ("recordings") as Button;
		var start_stop = builder.get_object ("start_stop") as Button;

		var chooser = new FileChooserDialog ("Select Recording Directory", window, FileChooserAction.SELECT_FOLDER, "Disable", ResponseType.CANCEL, "Select", ResponseType.ACCEPT, null);

		var display = Gdk.Display.get_default ();
		for (int i = 0; i < display.get_n_monitors (); i++) {
			video_input.append_text (display.get_monitor (i).model);
		}

		var monitor = new DeviceMonitor ();
		monitor.add_filter ("Audio/Source", null);
		monitor.get_devices ().foreach ((device) => {
			var element = device.create_element (null) as dynamic Gst.Element;
			if (element.get_factory ().get_name () != "pulsesrc")
				return;
//			var props = entry.get_properties ();
//			if (props.get_string ("device.class") == "sound")
				audio_input.insert (1, element.device, device.display_name);
		});

		window.delete_event.connect (() => {
			if (pipeline != null) {
				var dialog = new MessageDialog (window, 0, Gtk.MessageType.QUESTION, ButtonsType.YES_NO, "Quit Mincer?");
				dialog.secondary_text = "Mincer is currently running. Are you sure you want to stop processing and quit the application?";
				var response = dialog.run ();
				dialog.destroy ();

				if (response == ResponseType.NO) {
					return true;
				}
				stop ();
			}

			var key_file = new KeyFile ();

			key_file.set_string ("mincer", "url", url.text);
			key_file.set_integer ("mincer", "video_input", video_input.active);
			key_file.set_integer ("mincer", "video_resolution", video_resolution.active);
			key_file.set_integer ("mincer", "video_framerate", video_framerate.active);
			key_file.set_double ("mincer", "video_speed", Math.round (video_speed.adjustment.value));
			key_file.set_double ("mincer", "video_bitrate", Math.round (video_bitrate.adjustment.value));
			key_file.set_integer ("mincer", "audio_input", audio_input.active);
			key_file.set_double ("mincer", "audio_bitrate", Math.round (audio_bitrate.adjustment.value));

			if (recordings.label != "- Disabled -") {
				key_file.set_string ("mincer", "recordings", chooser.get_filename ());
			} else {
				key_file.set_string ("mincer", "recordings", "");
			}

			try {
				key_file.save_to_file (Environment.get_home_dir () + "/.mincer.conf");
			} catch (GLib.Error e) {
			}

			return false;
		});

		video_speed.adjustment.value_changed.connect ((adjustment) => {
			const string[] speeds = {
				"None", "Ultrafast", "Superfast", "Veryfast", "Faster", "Fast",
				"Medium", "Slow", "Slower", "Veryslow", "Placebo"
			};

			var video_speed_label = builder.get_object ("video_speed_label") as Label;
			var idx = (int)Math.round (adjustment.value);

			video_speed_label.label = "Video Encoder Speed - " + speeds[idx];
		});

		video_bitrate.adjustment.value_changed.connect ((adjustment) => {
			var video_bitrate_label = builder.get_object ("video_bitrate_label") as Label;
			var num = (int)Math.round (adjustment.value);

			video_bitrate_label.label = "Video Bitrate - " + num.to_string () + " kbps";

			if (pipeline != null) {
				var encoder = pipeline.get_by_name ("video_encoder") as dynamic Element;
				encoder.bitrate = num;
			}
		});

		audio_bitrate.adjustment.value_changed.connect ((adjustment) => {
			var audio_bitrate_label = builder.get_object ("audio_bitrate_label") as Label;
			var num = (int)Math.round (adjustment.value);

			audio_bitrate_label.label = "Audio Bitrate - " + num.to_string () + " kbps";
		});

		audio_mute.toggled.connect (() => {
			var audio = pipeline.get_by_name ("audio") as dynamic Element;

			audio.mute = audio_mute.active;
		});

		recordings.clicked.connect (() => {
			if (chooser.run () == ResponseType.ACCEPT) {
				recordings.label = chooser.get_filename ();

				var label = recordings.get_child () as Label;

				label.ellipsize = Pango.EllipsizeMode.MIDDLE;
				label.max_width_chars = 40;
			} else {
				recordings.label = "- Disabled -";
			}
			chooser.hide ();
		});

		start_stop.clicked.connect (() => {
			if (pipeline == null) {
				var geometry = display.get_monitor(video_input.active).geometry;
				var endx = geometry.x + geometry.width - 1;
				var endy = geometry.y + geometry.height - 1;

				int width = 0, height = 0;
				video_resolution.get_active_text ().scanf ("%dx%d", &width, &height);

				var tmp = "";
				tmp += "ximagesrc use-damage=false show-pointer=true ";
				tmp += "startx=" + geometry.x.to_string () + " starty=" + geometry.y.to_string () + " endx=" + endx.to_string () + " endy=" + endy.to_string () + " ! ";
				tmp += "queue ! video/x-raw, framerate=" + video_framerate.get_active_text () + "/1 ! ";
				tmp += "videoscale method=lanczos ! video/x-raw, ";
				tmp += "width=" + width.to_string () + ", height=" + height.to_string () + " ! ";
				tmp += "queue ! videoconvert ! x264enc name=video_encoder ";
				tmp += "bitrate=" + ((int)Math.round (video_bitrate.adjustment.value)).to_string () + " ";
				tmp += "speed-preset=" + ((int)Math.round (video_speed.adjustment.value)).to_string () + " ! ";
				tmp += "video/x-h264, profile=main ! h264parse ! tee name=video_tee ";

				if (audio_input.active == 0) {
					tmp += "audiotestsrc is-live=true wave=silence ! ";
				} else {
					tmp += "pulsesrc name=audio device=" + audio_input.active_id + " ! ";
				}
				tmp += "queue ! audioconvert ! audioresample ! audio/x-raw, channels=2, rate={ 44100, 48000 } ! ";
				tmp += "voaacenc bitrate=" + ((int)Math.round (audio_bitrate.adjustment.value) * 1000).to_string () + " ! ";
				tmp += "aacparse ! tee name=audio_tee ";

				if (url.text == "" && recordings.label == "- Disabled -") {
					tmp += "video_tee. ! queue ! fakesink ";
					tmp += "audio_tee. ! queue ! fakesink ";
				}

				if (url.text != "") {
					tmp += "video_tee. ! queue ! flvmux name=flv_mux ! rtmpsink location=\"" + url.text + "\" ";
					tmp += "audio_tee. ! queue max-size-bytes=0 max-size-buffers=0 max-size-time=4000000000 ! flv_mux. ";
				}

				if (recordings.label != "- Disabled -") {
					var now = new GLib.DateTime.now_local ();

					tmp += "video_tee. ! queue ! mp4mux name=mp4_mux ! filesink location=\"" + chooser.get_filename () + "/mincer_" + now.format("%Y-%m-%d_%H%M%S") + ".mp4\" ";
					tmp += "audio_tee. ! queue max-size-bytes=0 max-size-buffers=0 max-size-time=4000000000 ! mp4_mux. ";
				}

				try {
					pipeline = parse_launch (tmp) as Pipeline;
				} catch (GLib.Error e) {
					var dialog = new MessageDialog (window, 0, Gtk.MessageType.ERROR, ButtonsType.CLOSE, "%s", e.message);
					dialog.run ();
					dialog.destroy ();
					return;
				}

				pipeline.bus.add_watch (Priority.DEFAULT, (bus, message) => {
					switch (message.type) {
						case Gst.MessageType.ERROR:
							GLib.Error e;
							message.parse_error (out e, null);
							var dialog = new MessageDialog (window, 0, Gtk.MessageType.ERROR, ButtonsType.CLOSE, "%s", e.message);
							dialog.run ();
							dialog.destroy ();
							break;
						default:
							break;
					}
					return true;
				});

				pipeline.set_state (State.PLAYING);

				var start = new GLib.DateTime.now_utc ();
				Timeout.add (100, () => {
					var elapsed = builder.get_object ("elapsed") as Label;

					if (pipeline == null) {
						elapsed.label = "00:00:00";
						return false;
					}

					var now = new GLib.DateTime.now_utc ();
					var diff = new GLib.DateTime.from_unix_utc (now.to_unix () - start.to_unix ());

					elapsed.label = diff.format ("%H:%M:%S");
					return true;
				});

				url.visibility = false;
				url.sensitive = false;

				video_input.sensitive = false;
				video_resolution.sensitive = false;
				video_framerate.sensitive = false;
				video_speed.sensitive = false;
				audio_input.sensitive = false;
				audio_bitrate.sensitive = false;
				recordings.sensitive = false;

				if (audio_input.active != 0) {
					audio_mute.sensitive = true;
				}

				start_stop.label = "Stop";
			} else {
				stop ();

				url.visibility = true;
				url.sensitive = true;

				video_input.sensitive = true;
				video_resolution.sensitive = true;
				video_framerate.sensitive = true;
				video_speed.sensitive = true;
				audio_input.sensitive = true;
				audio_bitrate.sensitive = true;
				recordings.sensitive = true;

				audio_mute.sensitive = false;
				audio_mute.active = false;

				start_stop.label = "Start";
			}
		});

		var key_file = new KeyFile ();

		try {
			key_file.load_from_file (Environment.get_home_dir () + "/.mincer.conf", KeyFileFlags.NONE);

			url.text = key_file.get_string ("mincer", "url");
			video_input.active = key_file.get_integer ("mincer", "video_input");
			video_resolution.active = key_file.get_integer ("mincer", "video_resolution");
			video_framerate.active = key_file.get_integer ("mincer", "video_framerate");
			video_speed.adjustment.value = key_file.get_double ("mincer", "video_speed");
			video_bitrate.adjustment.value = key_file.get_double ("mincer", "video_bitrate");
			audio_input.active = key_file.get_integer ("mincer", "audio_input");
			audio_bitrate.adjustment.value = key_file.get_double ("mincer", "audio_bitrate");

			var record_value = key_file.get_string ("mincer", "recordings");

			if (record_value != "") {
				chooser.set_filename (record_value);
				recordings.label = record_value;

				var label = recordings.get_child () as Label;

				label.ellipsize = Pango.EllipsizeMode.MIDDLE;
				label.max_width_chars = 40;
			}
		} catch (GLib.Error e) {
		}

		window.application = this;
		window.show_all ();
	}

	private void stop () {
		var eos = new Event.eos ();
		pipeline.send_event (eos);
		pipeline.bus.timed_pop_filtered (CLOCK_TIME_NONE, Gst.MessageType.EOS);
		pipeline.set_state (State.NULL);
		pipeline = null;
	}

	public static int main (string[] args) {
		Gtk.init (ref args);
		Gst.init (ref args);

		return new Mincer ().run (args);
	}
}
