"""
Applet: TorBox Status
Summary: Monitor TorBox status
Description: Shows the current status of TorBox services from status.torbox.app and lists any services that are degraded, down or under maintenance.
Author: Jeremy Blaker
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "canvas", "render")
load("schema.star", "schema")

STATUS_URL = "https://status.torbox.app/index.json"

WIDTH, HEIGHT = canvas.size()
SCALE = 2 if canvas.is2x() else 1

HEADER_FONT = "terminus-16" if canvas.is2x() else "tb-8"
BODY_FONT = "terminus-12" if canvas.is2x() else "tom-thumb"
HEADER_HEIGHT = 9 * SCALE

STATUS_COLORS = {
    "operational": "#0c0",
    "degraded": "#fc0",
    "maintenance": "#39f",
    "downtime": "#f00",
}

STATUS_LABELS = {
    "operational": "All systems operational",
    "degraded": "Degraded performance",
    "maintenance": "Under maintenance",
    "downtime": "Outage",
}

# Worst first, used to sort affected services.
STATUS_RANK = {
    "downtime": 0,
    "degraded": 1,
    "maintenance": 2,
}

def status_color(status):
    return STATUS_COLORS.get(status, "#fc0")

def header(state):
    return render.Box(
        width = WIDTH,
        height = HEADER_HEIGHT,
        color = status_color(state),
        child = render.Text("TorBox", font = HEADER_FONT, color = "#000"),
    )

def message(text, color):
    return render.Box(
        width = WIDTH,
        height = HEIGHT - HEADER_HEIGHT,
        child = render.WrappedText(
            content = text,
            font = BODY_FONT,
            color = color,
            align = "center",
            width = WIDTH - 2 * SCALE,
        ),
    )

def service_row(resource):
    dot = 3 * SCALE
    return render.Padding(
        pad = (SCALE, SCALE, 0, 0),
        child = render.Row(
            cross_align = "start",
            children = [
                render.Padding(
                    pad = (0, SCALE, SCALE, 0),
                    child = render.Box(width = dot, height = dot, color = status_color(resource["status"])),
                ),
                render.WrappedText(
                    content = resource["public_name"],
                    font = BODY_FONT,
                    width = WIDTH - dot - 2 * SCALE,
                ),
            ],
        ),
    )

def main():
    resp = http.get(STATUS_URL, ttl_seconds = 240)
    if resp.status_code != 200:
        return []

    data = json.decode(resp.body())
    state = data["data"]["attributes"].get("aggregate_state", "operational")

    affected = [
        item["attributes"]
        for item in data.get("included", [])
        if item["type"] == "status_page_resource" and item["attributes"]["status"] != "operational"
    ]
    affected = sorted(affected, key = lambda r: (STATUS_RANK.get(r["status"], 1), r["position"]))

    if not affected:
        body = message(STATUS_LABELS.get(state, state.capitalize()), status_color(state))
    else:
        body = render.Marquee(
            height = HEIGHT - HEADER_HEIGHT,
            scroll_direction = "vertical",
            offset_end = HEIGHT - HEADER_HEIGHT,
            delay = 30,
            child = render.Column(children = [service_row(r) for r in affected]),
        )

    return render.Root(
        delay = 50 // SCALE,
        child = render.Column(children = [header(state), body]),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [],
    )
