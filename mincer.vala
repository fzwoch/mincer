using Gtk;
using Gst;

const string[] speeds = {
	"None", "Ultrafast", "Superfast", "Veryfast", "Faster", "Fast",
	"Medium", "Slow", "Slower", "Veryslow", "Placebo"
};

class Mincer : Gtk.Application {
	Pipeline pipeline = null;

	public override void activate () {
		var builder = new Builder.from_file ("mincer.glade");

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
		var chooser = builder.get_object ("chooser") as FileChooserDialog;
		var chooser_disable = builder.get_object ("chooser_disable") as Button;
		var chooser_select = builder.get_object ("chooser_select") as Button;

		var display = Gdk.Display.get_default ();
		for (int i = 0; i < display.get_n_monitors (); i++) {
			video_input.append_text(display.get_monitor (i).model);
		}
		video_input.active = 0;

		var monitor = new DeviceMonitor ();
		monitor.add_filter ("Audio/Source", null);
		monitor.get_devices ().foreach ((entry) => {
			audio_input.insert_text (1, entry.display_name);
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
			return false;
		});

		video_speed.adjustment.value_changed.connect ((adjustment) => {
			var video_speed_label = builder.get_object ("video_speed_label") as Label;
			var idx = (int)(adjustment.value + 0.5);

			video_speed_label.label = "Video Encoder Speed - " + speeds[idx];
		});

		video_bitrate.adjustment.value_changed.connect ((adjustment) => {
			var video_bitrate_label = builder.get_object ("video_bitrate_label") as Label;
			var num = (int)(adjustment.value + 0.5);

			video_bitrate_label.label = "Video Bitrate - " + num.to_string () + " kbps";

			if (pipeline != null) {
				var encoder = pipeline.get_by_name ("video_encoder") as dynamic Element;
				encoder.bitrate = num;
			}
		});

		audio_bitrate.adjustment.value_changed.connect ((adjustment) => {
			var audio_bitrate_label = builder.get_object ("audio_bitrate_label") as Label;
			var num = (int)(adjustment.value + 0.5);

			audio_bitrate_label.label = "Audio Bitrate - " + num.to_string () + " kbps";
		});

		recordings.clicked.connect (() => {
			chooser.run ();
		});

		chooser.delete_event.connect (() => {
			chooser.hide ();
			return true;
		});

		chooser_disable.clicked.connect (() => {
			chooser.hide ();
			recordings.label = "- Disabled -";
		});

		chooser_select.clicked.connect (() => {
			chooser.hide ();
			recordings.label = chooser.get_filename ();
		});

		start_stop.clicked.connect ((button) => {
			if (pipeline == null) {
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

				button.label = "Stop";

				int width = 0, height = 0;
				video_resolution.get_active_text ().scanf ("%dx%d", &width, &height);

				string tmp = "";
				tmp += "ximagesrc use-damage=false show-pointer=true ";
				tmp += "display-name=:0." + video_input.active.to_string () + " ! ";
				tmp += "video/x-raw, framerate=" + video_framerate.get_active_text () + "/1 ! ";
				tmp += "videoscale method=lanczos ! video/x-raw, ";
				tmp += "width=" + width.to_string () + ", height=" + height.to_string () + " ! ";
				tmp += "videoconvert ! x264enc tune=zerolatency name=video_encoder ";
				tmp += "bitrate=" + ((int)(video_bitrate.adjustment.value + 0.5)).to_string () + " ! ";
				tmp += "video/x-h264, profile=main ! h264parse ! tee name=video_tee ";

				if (audio_input.active == 0) {
					tmp += "audiotestsrc is-live=true wave=silence ! ";
				} else {
					tmp += "pulsesrc device=" + (audio_input.active - 1).to_string () + " ! ";
				}
				tmp += "audioconvert ! audioresample ! audio/x-raw, channels=2, rate={ 44100, 48000 } ! ";
				tmp += "voaacenc bitrate=" + ((int)(audio_bitrate.adjustment.value + 0.5) * 1000).to_string () + " ! ";
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
					tmp += "video_tee. ! queue ! mp4mux name=mp4_mux ! filesink location=\"" + chooser.get_filename () + "/bla.mp4\" ";
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

					if (button.label == "Start") {
						elapsed.label = "00:00:00";
						return false;
					}

					var now = new GLib.DateTime.now_utc ();
					var diff = new GLib.DateTime.from_unix_utc (now.to_unix () - start.to_unix ());

					elapsed.label = diff.format ("%H:%M:%S");
					return true;
				});
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

				button.label = "Start";
			}
		});

		window.application = this;
		window.show_all ();
	}

	private void stop () {
		if (pipeline != null) {
			var eos = new Event.eos ();
			pipeline.send_event (eos);
			pipeline.bus.timed_pop_filtered (CLOCK_TIME_NONE, Gst.MessageType.EOS);
			pipeline.set_state (State.NULL);
			pipeline.unref ();
			pipeline = null;
		}
	}

	public static int main (string[] args) {
		Gst.init (ref args);

		return new Mincer ().run (args);
	}
}
