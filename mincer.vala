using Gtk;
using Gst;
using PulseAudio;

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

		var display = new X.Display ();
		for (int i = 0; i < display.number_of_screens (); i++) {
			switch (i) {
				case 0:
					video_input.append_text("Primary Screen");
					break;
				case 1:
					video_input.append_text("Secondary Screen");
					break;
				case 2:
					video_input.append_text("Tertiary Screen");
					break;
				default:
					video_input.append_text("Screen #" + i.to_string ());
					break;
			}
		}
		video_input.active = 0;

		var pa_loop = new PulseAudio.MainLoop ();
		var pa_ctx = new PulseAudio.Context (pa_loop.get_api (), "mincer");

		pa_ctx.connect ();

		while (true) {
			if (pa_ctx.get_state () == PulseAudio.Context.State.READY) {
				break;
			}
			pa_loop.iterate ();
		}

		var pa_op = pa_ctx.get_source_info_list ((context, info, eol) => {
			if (eol != 0) {
				return;
			}
			audio_input.append_text (info.description);
		});

		while (true) {
			if (pa_op.get_state () == PulseAudio.Operation.State.DONE) {
				break;
			}
			pa_loop.iterate ();
		}

		pa_ctx.disconnect ();

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

				var tmp = "ximagesrc use-damage=false show-pointer=true " +
				"display-name=:0." + video_input.active.to_string () + " ! " +
				"video/x-raw, framerate=" + video_framerate.get_active_text () + "/1 ! " +
				"videoscale method=lanczos ! video/x-raw, " +
				"width=" + width.to_string () + ", height=" + height.to_string () + " ! " +
				"videoconvert ! x264enc tune=zerolatency name=video_encoder bitrate=2000 ! video/x-h264, profile=main ! h264parse ! tee name=video_tee " +
				"pulsesrc ! audioconvert ! audioresample ! audio/x-raw, channels=2, rate={44100, 48000} ! " +
				"voaacenc bitrate=128000 ! aacparse ! tee name=audio_tee ";

		//		tmp += "video_tee. ! queue ! flvmux name=flv_mux ! rtmpsink location=rtmp:// ";
		//		tmp += "audio_tee. ! queue max-size-bytes=0 max-size-buffers=0 max-size-time=4000000000 ! flv_mux. ";

				tmp += "video_tee. ! queue ! mp4mux name=mp4_mux ! filesink location=bla.mp4 ";
				tmp += "audio_tee. ! queue max-size-bytes=0 max-size-buffers=0 max-size-time=4000000000 ! mp4_mux. ";

				try {
					pipeline = parse_launch (tmp) as Pipeline;
				} catch (GLib.Error e) {
					print (e.message);
				}
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
			pipeline.get_bus ().pop_filtered (Gst.MessageType.EOS);
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
