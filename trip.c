
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#ifndef TRIP_PATH
#define TRIP_PATH "/usr/bin/trip.sh"
#endif

/** export TRIP_CONFIG_DIR=$HOME/.trip **/
void set_trip_conf ()
{
  char const* rel = ".trip";
  char const* home = getenv ("HOME");
  char* conf;
  int len;

  if (! home) return;

  len = strlen (rel) + strlen (home) + 2;
  conf = (char*) malloc (len * sizeof (char));
  sprintf (conf, "%s/%s", home, rel);
  if (0 == access (conf, F_OK)) {
    setenv ("TRIP_CONFIG_DIR", conf, 1);
  }
  free (conf);
}

int main (int argc, char** argv)
{
  if (getenv ("TRIP_CONFIG_DIR")) {
    /* Skip.*/
  }
  else if (0 == access ("/etc/trip", F_OK)) {
    /* Prefer /etc/trip/.*/
    setenv ("TRIP_CONFIG_DIR", "/etc/trip", 1);
  }
  else {
    /* Fall through to use $HOME/.trip/.*/
    set_trip_conf ();
  }
  /* puts (getenv ("TRIP_CONFIG_DIR")); */

  argv[0] = TRIP_PATH;
  argv[argc] = 0;
  execv (TRIP_PATH, argv);
  perror ("execv failed");
  return EXIT_FAILURE;
}

