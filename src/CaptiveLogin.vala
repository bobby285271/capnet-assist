/***
    BEGIN LICENSE

    Copyright (C) 2015 elementary LLC.
    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE.  See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>

    END LICENSE
***/

public class ValaBrowser : Gtk.Window {

    private const string TITLE = "Log in";
    private const string DUMMY_URL = "http://elementary.io";
    
    private WebKit.WebView web_view;
    private Gtk.ToggleButton tls_button;
    private Gtk.Label title_label;
    
    public ValaBrowser () {
        set_default_size (1000, 680);
        set_keep_above (true);
        set_skip_taskbar_hint (true);

        create_widgets ();
        connect_signals ();
        setup_web_view ();
    }

    bool is_privacy_mode_enabled () {
        var privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
        bool privacy_mode = !privacy_settings.get_boolean ("remember-recent-files") || 
                            !privacy_settings.get_boolean ("remember-app-usage");
        return privacy_mode;
    }

    private void setup_web_view () {
        if (!is_privacy_mode_enabled ()) {
            var cookies_db_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                   Environment.get_user_config_dir (),
                                                   "midori",
                                                   "cookies.db");

            if (!FileUtils.test (cookies_db_path, FileTest.IS_REGULAR)) {
                debug ("No cookies.db found, not saving the cookies...\n");
                return;
            }

            var cookie_manager = web_view.get_context ().get_cookie_manager ();

            cookie_manager.set_accept_policy (WebKit.CookieAcceptPolicy.ALWAYS);
            cookie_manager.set_persistent_storage (cookies_db_path, WebKit.CookiePersistentStorage.SQLITE);
        }
    }

    private void create_widgets () {
        var header = new Gtk.HeaderBar ();
        header.set_show_close_button (true);
        header.get_style_context ().remove_class ("header-bar");

        this.set_titlebar (header);

        tls_button = new Gtk.ToggleButton ();
        tls_button.set_image (new Gtk.Image.from_icon_name ("content-loading-symbolic", Gtk.IconSize.BUTTON));
        var tls_button_style_context = tls_button.get_style_context ();
        tls_button_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        tls_button_style_context.add_class ("titlebutton");
        tls_button.set_sensitive (false);
        tls_button.toggled.connect (on_tls_button_click);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        hbox.set_margin_top (3);
        hbox.set_margin_bottom (3);
        hbox.pack_start (tls_button);

        title_label = new Gtk.Label (ValaBrowser.TITLE);
        title_label.get_style_context ().add_class (Gtk.STYLE_CLASS_TITLE);
        hbox.pack_start (title_label);

        header.set_custom_title (hbox);

        web_view = new WebKit.WebView ();

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scrolled_window.add (web_view);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.pack_start (scrolled_window, true, true, 0);

        add (vbox);
    }
    
    public bool isLoggedIn () {
        var network_monitor = NetworkMonitor.get_default ();

        // No connection is available at the moment, don't bother trying the
        // connectivity check
        if (network_monitor.get_connectivity () != NetworkConnectivity.FULL) {
            return true;
        }

        var page = "http://connectivitycheck.android.com/generate_204";
        debug ("Getting 204 page");

        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", page);

        session.send_message (message);

        debug ("Return code: %u", message.status_code);
        return message.status_code == 204;
    }

    private void update_tls_info () {
        TlsCertificate cert;
        TlsCertificateFlags cert_flags;
        Icon icon;
        bool is_secure;

        if (!web_view.get_tls_info (out cert, out cert_flags)) {
            // The page is served over HTTP
            is_secure = false;
        } else {
            // The page is served over HTTPS, if cert_flags is set then there's
            // some problem with the certificate provided by the website.
            is_secure = (cert_flags == 0);
        }

        if (is_secure) {
            icon = new ThemedIcon.from_names ({"channel-secure-symbolic", "security-high"});
            tls_button.set_tooltip_text (_("The page is served over a protected connection."));
        } else {
            icon = new ThemedIcon.from_names ({"channel-insecure-symbolic", "security-low"});
            tls_button.set_tooltip_text ("The page is served over an unprotected connection.");
        }

        var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.BUTTON);
        tls_button.set_image (image);
    }

    private void on_tls_button_click () {
        TlsCertificate cert;
        TlsCertificateFlags cert_flags;

        if (!tls_button.get_active ()) {
            return;
        }
        if (!web_view.get_tls_info (out cert, out cert_flags)) {
            tls_button.set_active (false);
            return;
        }

        var popover = new Gtk.Popover (tls_button);
        popover.set_border_width (12);

        // Wonderful hack we got here, the vapi for Gtk has a wrong definition
        // for the get_gicon () method, it's not reported as an out parameter
        // hence we're stuck with passing everything by value.
        // Since we're badass we pass the INVALID constant that evaluates to 0
        // which is casted into a NULL pointer and allows us to save the date.
        Icon button_icon;
        (tls_button.get_image () as Gtk.Image).get_gicon (out button_icon, Gtk.IconSize.INVALID);

        var icon = new Gtk.Image.from_gicon (button_icon, Gtk.IconSize.DIALOG);
        icon.get_style_context ().add_class ("success");
        icon.valign = Gtk.Align.START;

        var primary_text = new Gtk.Label (web_view.get_uri());
        primary_text.get_style_context ().add_class ("h3");
        primary_text.halign = Gtk.Align.START;
        primary_text.margin_start = 9;

        var secondary_text = new Gtk.Label (tls_button.get_tooltip_text ());
        secondary_text.get_style_context ().add_class ("success");
        secondary_text.halign = Gtk.Align.START;
        secondary_text.margin_start = 9;

        var gcr_cert = new Gcr.SimpleCertificate (cert.certificate.data);
        var cert_details = new Gcr.CertificateWidget (gcr_cert);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 3;
        grid.attach (icon, 0, 0, 1, 2);
        grid.attach (primary_text, 1, 0, 1, 1);
        grid.attach (secondary_text, 1, 1, 1, 1);
        grid.attach (cert_details, 1, 2, 1, 1);
        
        popover.add (grid);

        // This hack has been borrowed from midori, the widget provided by the
        // GCR library would fail with an assertion when the 'details' button was
        // clicked
        popover.button_press_event.connect ((event) => {
            return true;
        });

        popover.button_release_event.connect ((event) => {
            var child = popover.get_child ();
            var event_widget = Gtk.get_event_widget (event);

            if (child != null && event.window == popover.get_window ()) {
                Gtk.Allocation child_alloc;
                popover.get_allocation (out child_alloc);

                if (event.x < child_alloc.x ||
                    event.x > child_alloc.x + child_alloc.width ||
                    event.y < child_alloc.y ||
                    event.y > child_alloc.y + child_alloc.height) {
                    popover.hide ();
                    tls_button.set_active (false);
                }
            } else if (event_widget != null && !event_widget.is_ancestor (popover)) {
                popover.hide ();
                tls_button.set_active (false);
            }

            return true;
        });

        popover.show_all ();

        return;
    }

    private void connect_signals () {
        this.destroy.connect (Gtk.main_quit);
        //should title change?
        web_view.notify["title"].connect ((view, param_spec) => {
            title_label.set_text (web_view.get_title ());
        });

        web_view.load_changed.connect ((view, event) => {
            switch (event) {
                case WebKit.LoadEvent.FINISHED:
                    if (isLoggedIn ()) {
                        debug ("Logged in!");
                        Gtk.main_quit ();
                    } else {
                        debug ("Still not logged in.");
                    }
                    break;

                case WebKit.LoadEvent.STARTED:
                    tls_button.set_sensitive (false);
                    break;

                case WebKit.LoadEvent.COMMITTED:
                    update_tls_info ();
                    tls_button.set_sensitive (true);
                    break;
            }
        });

        web_view.load_failed.connect ((event, uri, error) => {
            // The user has canceled the page loading eg. by clicking on a link.
            if ((Error)error is WebKit.NetworkError.CANCELLED) {
                return true;
            }

            Gtk.main_quit ();
            return true;
        });
    }

    public void start () {
        show_all ();
        web_view.load_uri (ValaBrowser.DUMMY_URL);
    }

    public static int main (string[] args) {
        Gtk.init (ref args);

        var browser = new ValaBrowser ();

        if (!browser.isLoggedIn ()) {
            debug ("Opening browser to login");
            browser.start ();
            Gtk.main ();
        } else {
            debug ("Already logged in and connected, shutting down.");
        }

        return 0;
    }
}
