
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>


    /* export TRIP_CONFIG_DIR=$HOME/.trip */
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
    setenv ("TRIP_CONFIG_DIR", conf, 1);
    free (conf);
}

int main (int argc, char** argv)
{
    set_trip_conf ();
        /* puts (getenv ("TRIP_CONFIG_DIR")); */

    argv[0] = TRIP_PATH;
    argv[argc] = 0;
    execv (TRIP_PATH, argv);
    perror ("execv failed");
    return EXIT_FAILURE;
}

