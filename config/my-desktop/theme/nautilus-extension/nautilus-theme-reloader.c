#include <nautilus-extension.h>
#include <gtk/gtk.h>
#include <gio/gio.h>

static GtkCssProvider *css_provider = NULL;
static GFileMonitor   *css_monitor  = NULL;
static guint           debounce_id  = 0;
static gboolean        initialized  = FALSE;

static gboolean do_reload_css(gpointer user_data) {
    debounce_id = 0;
    if (!css_provider) {
        return G_SOURCE_REMOVE;
    }

    const char *home = g_get_home_dir();
    char *css_path = g_build_filename(home, ".config", "gtk-4.0", "gtk.css", NULL);
    if (g_file_test(css_path, G_FILE_TEST_EXISTS)) {
        g_print("[nautilus-theme-reloader] Live reloading CSS from %s\n", css_path);
        gtk_css_provider_load_from_path(css_provider, css_path);
    }
    g_free(css_path);
    return G_SOURCE_REMOVE;
}

static void schedule_reload(void) {
    if (debounce_id > 0) {
        g_source_remove(debounce_id);
    }
    // 60ms debounce for smooth non-blocking reload
    debounce_id = g_timeout_add(60, do_reload_css, NULL);
}

static void on_css_changed(GFileMonitor      *monitor,
                           GFile              *file,
                           GFile              *other_file,
                           GFileMonitorEvent   event_type,
                           gpointer            user_data) {
    if (event_type == G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT ||
        event_type == G_FILE_MONITOR_EVENT_CHANGED ||
        event_type == G_FILE_MONITOR_EVENT_CREATED) {
        schedule_reload();
    }
}

static gboolean init_theme_watcher(gpointer user_data) {
    if (initialized) {
        return G_SOURCE_REMOVE;
    }

    GdkDisplay *display = gdk_display_get_default();
    if (!display) {
        return G_SOURCE_CONTINUE;
    }

    initialized = TRUE;

    css_provider = gtk_css_provider_new();
    gtk_style_context_add_provider_for_display(
        display,
        GTK_STYLE_PROVIDER(css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER + 50
    );

    // Initial load
    do_reload_css(NULL);

    // Watch ~/.config/gtk-4.0/gtk.css for changes
    const char *home = g_get_home_dir();
    char *css_path = g_build_filename(home, ".config", "gtk-4.0", "gtk.css", NULL);
    GFile *file = g_file_new_for_path(css_path);
    GError *error = NULL;

    css_monitor = g_file_monitor_file(file, G_FILE_MONITOR_NONE, NULL, &error);
    if (css_monitor) {
        g_signal_connect(css_monitor, "changed", G_CALLBACK(on_css_changed), NULL);
        g_print("[nautilus-theme-reloader] Live theme watcher active for %s\n", css_path);
    } else if (error) {
        g_printerr("[nautilus-theme-reloader] Failed to create monitor: %s\n", error->message);
        g_clear_error(&error);
    }

    g_object_unref(file);
    g_free(css_path);

    return G_SOURCE_REMOVE;
}

/* Nautilus Extension API */
void nautilus_module_initialize(GTypeModule *module) {
    g_idle_add(init_theme_watcher, NULL);
}

void nautilus_module_shutdown(void) {
    if (debounce_id > 0) {
        g_source_remove(debounce_id);
        debounce_id = 0;
    }
    if (css_monitor) {
        g_file_monitor_cancel(css_monitor);
        g_object_unref(css_monitor);
        css_monitor = NULL;
    }
    if (css_provider) {
        g_object_unref(css_provider);
        css_provider = NULL;
    }
    initialized = FALSE;
}

void nautilus_module_list_types(const GType **types, int *num_types) {
    *types = NULL;
    *num_types = 0;
}

/* Fallback constructor in case loaded via other means */
__attribute__((constructor))
static void ctor_init(void) {
    g_idle_add(init_theme_watcher, NULL);
}
