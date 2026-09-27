#include "my_application.h"

int main(int argc, char** argv) {
  // Suppress Mesa / EGL probing warnings in virtual/containerized DRI environments
  g_setenv("EGL_LOG_LEVEL", "fatal", FALSE);
  g_setenv("MESA_LOG_LEVEL", "fatal", FALSE);

  // Ensure default cursor theme is available to prevent GDK cursor lookup warnings
  g_setenv("XCURSOR_THEME", "Adwaita", FALSE);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
