#include <stdio.h>
#include <string.h>

#define MAX_LINE 4096
#define MAX_FIELD 1024

static void copy_field(char *destination, size_t size, const char *source) {
    size_t i = 0;

    while (source[i] != '\0' && source[i] != '\t' &&
           source[i] != '\r' && source[i] != '\n' && i + 1 < size) {
        destination[i] = source[i];
        i++;
    }

    destination[i] = '\0';
}

static int format_ics_date(const char *iso_date, char *output, size_t size) {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;

    if (sscanf(iso_date, "%d-%d-%dT%d:%d:%d",
               &year, &month, &day, &hour, &minute, &second) != 6) {
        return 0;
    }

    return snprintf(output, size, "%04d%02d%02dT%02d%02d%02dZ",
                    year, month, day, hour, minute, second) > 0;
}

static void write_escaped_text(FILE *file, const char *text) {
    for (size_t i = 0; text[i] != '\0'; i++) {
        if (text[i] == ',' || text[i] == ';' || text[i] == '\\') {
            fputc('\\', file);
        }
        fputc(text[i], file);
    }
}

int main(void) {
    FILE *input = fopen("canvas-items.tsv", "r");
    FILE *output;
    char line[MAX_LINE];
    int event_count = 0;

    if (input == NULL) {
        fprintf(stderr, "Nao foi possivel abrir canvas-items.tsv\n");
        return 1;
    }

    output = fopen("canvas-events.ics", "w");
    if (output == NULL) {
        fprintf(stderr, "Nao foi possivel criar canvas-events.ics\n");
        fclose(input);
        return 1;
    }

    fprintf(output, "BEGIN:VCALENDAR\r\n");
    fprintf(output, "VERSION:2.0\r\n");
    fprintf(output, "PRODID:-//Canvas Sync//PUC Campinas//PT-BR\r\n");
    fprintf(output, "CALSCALE:GREGORIAN\r\n");

    if (fgets(line, sizeof(line), input) == NULL) {
        fprintf(stderr, "canvas-items.tsv esta vazio\n");
        fclose(input);
        fclose(output);
        remove("canvas-events.ics");
        return 1;
    }

    while (fgets(line, sizeof(line), input) != NULL) {
        char type[MAX_FIELD];
        char course_id[MAX_FIELD];
        char task_id[MAX_FIELD];
        char course_name[MAX_FIELD];
        char title[MAX_FIELD];
        char due_at[MAX_FIELD];
        char html_url[MAX_FIELD];
        char start_date[32];
        char uid[128];
        char *field;

        copy_field(type, sizeof(type), line);

        field = strchr(line, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(course_id, sizeof(course_id), field + 1);

        field = strchr(field + 1, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(task_id, sizeof(task_id), field + 1);

        field = strchr(field + 1, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(course_name, sizeof(course_name), field + 1);

        field = strchr(field + 1, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(title, sizeof(title), field + 1);

        field = strchr(field + 1, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(due_at, sizeof(due_at), field + 1);

        field = strchr(field + 1, '\t');
        if (field == NULL) {
            continue;
        }
        copy_field(html_url, sizeof(html_url), field + 1);

        if ((strcmp(type, "assignment") != 0 && strcmp(type, "quiz") != 0) ||
            due_at[0] == '\0' ||
            !format_ics_date(due_at, start_date, sizeof(start_date))) {
            continue;
        }

        snprintf(uid, sizeof(uid), "canvas-%.*s-%.*s@puc-campinas",
                 32, course_id, 32, task_id);
        fprintf(output, "BEGIN:VEVENT\r\n");
        fprintf(output, "UID:%s\r\n", uid);
        fprintf(output, "DTSTAMP:%s\r\n", start_date);
        fprintf(output, "DTSTART:%s\r\n", start_date);
        fprintf(output, "SUMMARY:");
        write_escaped_text(output, course_name);
        fprintf(output, " - ");
        write_escaped_text(output, title);
        fprintf(output, "\r\n");

        if (html_url[0] != '\0') {
            fprintf(output, "URL:%s\r\n", html_url);
        }

        fprintf(output, "DESCRIPTION:Prazo no Canvas - ");
        write_escaped_text(output, course_name);
        if (html_url[0] != '\0') {
            fprintf(output, "\\nLink: ");
            write_escaped_text(output, html_url);
        }
        fprintf(output, "\r\n");
        fprintf(output, "END:VEVENT\r\n");
        event_count++;
    }

    fprintf(output, "END:VCALENDAR\r\n");
    fclose(input);
    fclose(output);

    printf("Eventos gerados: %d\n", event_count);
    return 0;
}
