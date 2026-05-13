#include <mosquitto.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

struct demo_state {
    int connected;
    int subscribed;
    int received;
    char expected[128];
};

static void on_connect(struct mosquitto *mosq, void *userdata, int rc)
{
    struct demo_state *state = userdata;

    (void)mosq;
    if (rc == 0) {
        state->connected = 1;
        return;
    }

    fprintf(stderr, "mqtt-demo: connect failed rc=%d\n", rc);
}

static void on_subscribe(struct mosquitto *mosq, void *userdata, int mid, int qos_count, const int *granted_qos)
{
    struct demo_state *state = userdata;

    (void)mosq;
    (void)mid;
    (void)qos_count;
    (void)granted_qos;
    state->subscribed = 1;
}

static void on_message(struct mosquitto *mosq, void *userdata, const struct mosquitto_message *message)
{
    struct demo_state *state = userdata;

    (void)mosq;
    if (!message || !message->payload) {
        return;
    }

    printf("mqtt-demo: received topic=%s payload=%s\n",
           message->topic ? message->topic : "(null)",
           (const char *)message->payload);
    if (strcmp((const char *)message->payload, state->expected) == 0) {
        state->received = 1;
    }
}

static int wait_flag(const volatile int *flag, int timeout_ms)
{
    int loops = timeout_ms / 100;

    while (loops-- > 0) {
        if (*flag) {
            return 0;
        }
        usleep(100 * 1000);
    }

    return -1;
}

int main(void)
{
    static const char *topic = "imx6ull/mqtt-demo";
    struct mosquitto *mosq = NULL;
    struct demo_state state;
    int rc;
    int connect_attempts;

    memset(&state, 0, sizeof(state));
    snprintf(state.expected, sizeof(state.expected), "mqtt-demo-%ld", (long)time(NULL));

    rc = mosquitto_lib_init();
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "mqtt-demo: mosquitto_lib_init failed rc=%d\n", rc);
        return 1;
    }

    mosq = mosquitto_new("mqtt-demo", true, &state);
    if (!mosq) {
        fprintf(stderr, "mqtt-demo: mosquitto_new failed\n");
        mosquitto_lib_cleanup();
        return 1;
    }

    mosquitto_connect_callback_set(mosq, on_connect);
    mosquitto_subscribe_callback_set(mosq, on_subscribe);
    mosquitto_message_callback_set(mosq, on_message);

    for (connect_attempts = 0; connect_attempts < 15; ++connect_attempts) {
        rc = mosquitto_connect(mosq, "127.0.0.1", 1883, 30);
        if (rc == MOSQ_ERR_SUCCESS) {
            break;
        }
        fprintf(stderr, "mqtt-demo: broker not ready yet rc=%d, retry=%d/15\n",
                rc, connect_attempts + 1);
        sleep(1);
    }
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "mqtt-demo: failed to connect to local broker\n");
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    rc = mosquitto_loop_start(mosq);
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "mqtt-demo: mosquitto_loop_start failed rc=%d\n", rc);
        mosquitto_disconnect(mosq);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    if (wait_flag(&state.connected, 5000) != 0) {
        fprintf(stderr, "mqtt-demo: timed out waiting for connect callback\n");
        mosquitto_loop_stop(mosq, true);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    rc = mosquitto_subscribe(mosq, NULL, topic, 0);
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "mqtt-demo: mosquitto_subscribe failed rc=%d\n", rc);
        mosquitto_loop_stop(mosq, true);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    if (wait_flag(&state.subscribed, 5000) != 0) {
        fprintf(stderr, "mqtt-demo: timed out waiting for subscribe callback\n");
        mosquitto_loop_stop(mosq, true);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    rc = mosquitto_publish(mosq, NULL, topic, (int)strlen(state.expected), state.expected, 0, false);
    if (rc != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "mqtt-demo: mosquitto_publish failed rc=%d\n", rc);
        mosquitto_loop_stop(mosq, true);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    if (wait_flag(&state.received, 5000) != 0) {
        fprintf(stderr, "mqtt-demo: timed out waiting for message loopback\n");
        mosquitto_loop_stop(mosq, true);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();
        return 1;
    }

    printf("mqtt-demo: loopback success topic=%s payload=%s\n", topic, state.expected);
    printf("MQTT_DEMO_OK\n");

    mosquitto_disconnect(mosq);
    mosquitto_loop_stop(mosq, true);
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 0;
}
