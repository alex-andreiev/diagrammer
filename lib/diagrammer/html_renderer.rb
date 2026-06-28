# frozen_string_literal: true

require 'erb'
require 'json'

module Diagrammer
  # Holds the standalone HTML template (inline CSS + JS card renderer); the bulk
  # of its length is that template string rather than Ruby logic.
  class HtmlRenderer # rubocop:disable Metrics/ClassLength
    TEMPLATE = <<~HTML
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title><%= ERB::Util.html_escape(title) %></title>
          <style>
            :root {
              color-scheme: light;
              --bg: #f6f1e8;
              --panel: #fbfcfd;
              --ink: #1f2933;
              --muted: #687385;
              --accent: #0f766e;
              --line: #9aa5b1;
              --card-border: #d2d9e0;
            }

            * { box-sizing: border-box; }

            body {
              margin: 0;
              min-height: 100vh;
              font-family: Georgia, "Times New Roman", serif;
              color: var(--ink);
              background:
                radial-gradient(circle at 20% 15%, rgba(15, 118, 110, 0.18), transparent 28rem),
                linear-gradient(135deg, #f6f1e8 0%, #e7dbc8 100%);
            }

            main {
              box-sizing: border-box;
              width: 100%;
              margin: 0;
              padding: 24px 16px 28px;
            }

            header { margin-bottom: 16px; }

            h1 {
              margin: 0 0 6px;
              font-size: clamp(1.8rem, 4vw, 3.2rem);
              letter-spacing: -0.05em;
            }

            header p { margin: 0; color: var(--muted); }

            .notice {
              margin-bottom: 16px;
              padding: 16px 18px;
              border: 1px solid rgba(180, 83, 9, 0.28);
              border-radius: 18px;
              background: rgba(254, 243, 199, 0.9);
              color: #92400e;
            }

            .toolbar {
              display: flex;
              align-items: center;
              gap: 10px;
              margin-bottom: 10px;
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
              font-size: 0.85rem;
              color: var(--muted);
            }

            .toolbar button {
              font: inherit;
              padding: 6px 12px;
              border: 1px solid var(--card-border);
              border-radius: 999px;
              background: #fff;
              color: var(--ink);
              cursor: pointer;
            }
            .toolbar button:hover { border-color: var(--accent); color: var(--accent); }
            .toolbar .spacer { flex: 1; }

            .viewport {
              position: relative;
              height: min(82vh, 940px);
              overflow: hidden;
              border: 1px solid rgba(31, 41, 51, 0.14);
              border-radius: 18px;
              background-color: var(--panel);
              background-image: radial-gradient(rgba(31, 41, 51, 0.10) 1px, transparent 1px);
              background-size: 22px 22px;
              box-shadow: 0 24px 80px rgba(31, 41, 51, 0.16);
              touch-action: none;
              cursor: grab;
            }
            .viewport.panning { cursor: grabbing; }

            .world {
              position: absolute;
              top: 0;
              left: 0;
              transform-origin: 0 0;
              will-change: transform;
            }

            .edges {
              position: absolute;
              top: 0;
              left: 0;
              overflow: visible;
              pointer-events: none;
            }
            .edges .link {
              fill: none;
              stroke: var(--line);
              stroke-width: 1.5;
              vector-effect: non-scaling-stroke;
            }
            .edges .marker {
              fill: none;
              stroke: var(--line);
              stroke-width: 1.5;
              stroke-linecap: round;
              stroke-linejoin: round;
              vector-effect: non-scaling-stroke;
            }
            .edges .edge.active .link,
            .edges .edge.active .marker {
              stroke: var(--accent);
              stroke-width: 2.25;
            }

            .card {
              position: absolute;
              min-width: 180px;
              background: #fff;
              border: 1px solid var(--card-border);
              border-radius: 8px;
              box-shadow: 0 6px 18px rgba(31, 41, 51, 0.12);
              font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
              font-size: 12px;
              overflow: hidden;
              cursor: grab;
              user-select: none;
            }
            .card.dragging { cursor: grabbing; box-shadow: 0 12px 28px rgba(31, 41, 51, 0.22); z-index: 5; }
            .card.dim { opacity: 0.25; }
            .card.focus { box-shadow: 0 0 0 2px var(--accent), 0 12px 28px rgba(31, 41, 51, 0.22); }

            .card-header {
              padding: 8px 12px;
              font-weight: 700;
              font-size: 13px;
              color: #fff;
              white-space: nowrap;
              letter-spacing: 0.01em;
              text-shadow: 0 1px 1px rgba(0, 0, 0, 0.18);
              box-shadow: inset 0 -1px 0 rgba(0, 0, 0, 0.12);
            }

            .col {
              display: flex;
              align-items: center;
              gap: 14px;
              padding: 4px 12px;
              border-top: 1px solid #eef1f4;
              white-space: nowrap;
            }
            .col .name { font-weight: 500; }
            .col .type {
              margin-left: auto;
              color: var(--muted);
              font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
              font-size: 11px;
            }
            .col .badge {
              font-family: ui-monospace, Menlo, Consolas, monospace;
              font-size: 9px;
              font-weight: 700;
              padding: 1px 4px;
              border-radius: 4px;
              letter-spacing: 0.04em;
            }
            .col .badge.pk { background: #fef3c7; color: #92400e; }
            .col .badge.fk { background: #dbeafe; color: #1e40af; }
            .col.is-pk .name { font-weight: 700; }
            .col.is-fk .name { color: #1e40af; }
            .col:hover { background: #f4f6f8; }
            .col.highlight { background: #f0fdfa; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1><%= ERB::Util.html_escape(title) %></h1>
              <p>Generated by Diagrammer. Standalone &mdash; no network needed.</p>
            </header>
            <% if notice %>
              <aside class="notice"><%= ERB::Util.html_escape(notice) %></aside>
            <% end %>
            <div class="toolbar">
              <button type="button" data-action="relayout">Re-layout</button>
              <button type="button" data-action="reset">Reset view</button>
              <button type="button" data-action="fit">Fit</button>
              <span class="spacer"></span>
              <span>Scroll to zoom &middot; drag background to pan &middot; drag a table to move it</span>
            </div>
            <div class="viewport" id="viewport">
              <div class="world" id="world">
                <svg class="edges" id="edges"></svg>
              </div>
            </div>
          </main>
          <script id="diagram-data" type="application/json"><%= data_json %></script>
          <script>
          (function () {
            "use strict";
            var data = JSON.parse(document.getElementById("diagram-data").textContent);
            var tables = data.tables || [];
            var relationships = data.relationships || [];

            var viewport = document.getElementById("viewport");
            var world = document.getElementById("world");
            var edges = document.getElementById("edges");
            var SVGNS = "http://www.w3.org/2000/svg";

            // Deterministic per-table header colour for visual variety.
            var PALETTE = [
              "#0f766e", "#1d4ed8", "#9333ea", "#be123c", "#b45309",
              "#047857", "#7c3aed", "#0e7490", "#a21caf", "#4d7c0f"
            ];
            function colorFor(name) {
              var h = 0;
              for (var i = 0; i < name.length; i++) { h = (h * 31 + name.charCodeAt(i)) >>> 0; }
              return PALETTE[h % PALETTE.length];
            }

            // ---- Build cards -------------------------------------------------
            var nodes = {};        // table_name -> node
            var order = [];        // stable iteration order
            tables.forEach(function (t) {
              var el = document.createElement("div");
              el.className = "card";
              var header = document.createElement("div");
              header.className = "card-header";
              header.style.background = colorFor(t.table_name);
              header.textContent = t.table_name;
              el.appendChild(header);

              var rows = {};       // column name -> row element
              (t.columns || []).forEach(function (c) {
                var row = document.createElement("div");
                row.className = "col" + (c.primary_key ? " is-pk" : "") + (c.foreign_key ? " is-fk" : "");
                var name = document.createElement("span");
                name.className = "name";
                name.textContent = c.name;
                row.appendChild(name);
                if (c.primary_key) { row.appendChild(badge("pk", "PK")); }
                if (c.foreign_key) { row.appendChild(badge("fk", "FK")); }
                var type = document.createElement("span");
                type.className = "type";
                type.textContent = c.type;
                row.appendChild(type);
                el.appendChild(row);
                rows[c.name] = row;
              });

              world.appendChild(el);
              var node = {
                name: t.table_name, el: el, rows: rows, columns: t.columns || [],
                x: 0, y: 0, w: 0, h: 0, vx: 0, vy: 0, edges: []
              };
              nodes[t.table_name] = node;
              order.push(node);
            });

            function badge(kind, text) {
              var b = document.createElement("span");
              b.className = "badge " + kind;
              b.textContent = text;
              return b;
            }

            // Measure rendered card sizes.
            order.forEach(function (n) {
              n.w = n.el.offsetWidth;
              n.h = n.el.offsetHeight;
            });

            // ---- Resolve relationship anchors -------------------------------
            // We only know table->table links. Try to anchor the line at the FK
            // column row ("<assoc>_id") when present, else at the card centre.
            var links = [];
            relationships.forEach(function (r) {
              var from = nodes[r.from], to = nodes[r.to];
              if (!from || !to) { return; }
              var fkName = (r.name || "") + "_id";
              var fkRow = from.rows[fkName] ? fkName : null;
              var pkCol = pkColumn(to);
              var link = { from: from, to: to, fkRow: fkRow, pkRow: pkCol, card: cardinality(r.macro), group: null };
              links.push(link);
              from.edges.push(link);
              to.edges.push(link);
            });

            function pkColumn(node) {
              for (var i = 0; i < node.columns.length; i++) {
                if (node.columns[i].primary_key) { return node.columns[i].name; }
              }
              return null;
            }

            // Map an association macro to crow's-foot cardinality at each end.
            function cardinality(macro) {
              switch (macro) {
                case "belongs_to": return { from: "many", to: "one" };
                case "has_one": return { from: "one", to: "one" };
                case "has_many": return { from: "one", to: "many" };
                case "has_and_belongs_to_many": return { from: "many", to: "many" };
                default: return { from: "one", to: "many" };
              }
            }

            // ---- Cluster layout ---------------------------------------------
            // Split the graph into connected components, lay each one out on its
            // own with a force simulation, then pack the components onto shelves.
            // This keeps related tables together and stops everything collapsing
            // into one central hairball.
            function layout() {
              if (order.length === 0) { return; }
              // Target the viewport's aspect ratio so the diagram fills the width
              // instead of growing tall (which leaves side gaps and vertical scroll).
              var target = clamp(viewport.clientWidth / Math.max(1, viewport.clientHeight), 1.3, 2.4);
              var boxes = connectedComponents().map(function (comp) {
                forceLayout(comp, componentLinks(comp), comp.length > 60 ? 380 : 260);
                var b = bbox(comp);
                comp.forEach(function (node) { node.x -= b.minX; node.y -= b.minY; });
                var w = b.w, h = b.h;
                // Widen tall clusters horizontally toward the target aspect.
                if (comp.length >= 4 && h > 0 && w / h < target) {
                  var factor = Math.min(target / (w / h), 2.2);
                  comp.forEach(function (node) { node.x *= factor; });
                  w *= factor;
                }
                return { comp: comp, w: w, h: h, area: w * h };
              });
              boxes.sort(function (a, b) { return b.area - a.area; });
              packComponents(boxes, target);
              order.forEach(place);
              drawEdges();
              fitView();
            }

            function connectedComponents() {
              var seen = {}, comps = [];
              order.forEach(function (start) {
                if (seen[start.name]) { return; }
                var queue = [start], comp = [];
                seen[start.name] = true;
                while (queue.length) {
                  var node = queue.pop();
                  comp.push(node);
                  node.edges.forEach(function (l) {
                    var other = l.from === node ? l.to : l.from;
                    if (!seen[other.name]) { seen[other.name] = true; queue.push(other); }
                  });
                }
                comps.push(comp);
              });
              return comps;
            }

            // All links inside a component (deduped via a transient flag).
            function componentLinks(comp) {
              var list = [];
              comp.forEach(function (node) {
                node.edges.forEach(function (l) {
                  if (!l._seen) { l._seen = true; list.push(l); }
                });
              });
              list.forEach(function (l) { l._seen = false; });
              return list;
            }

            function forceLayout(nodes, lnks, iterations) {
              var n = nodes.length;
              if (n === 1) { nodes[0].x = 0; nodes[0].y = 0; return; }
              var cols = Math.ceil(Math.sqrt(n));
              nodes.forEach(function (node, i) {
                node.x = (i % cols) * 320;
                node.y = Math.floor(i / cols) * 230;
                node.vx = 0; node.vy = 0;
              });

              var rep = 120000, ideal = 300;
              for (var step = 0; step < iterations; step++) {
                var cooling = 1 - step / iterations;
                for (var i = 0; i < n; i++) {
                  var a = nodes[i];
                  for (var j = i + 1; j < n; j++) {
                    var b = nodes[j];
                    var dx = (a.x + a.w / 2) - (b.x + b.w / 2);
                    var dy = (a.y + a.h / 2) - (b.y + b.h / 2);
                    var d2 = dx * dx + dy * dy + 0.01;
                    var d = Math.sqrt(d2);
                    var rf = rep / d2;
                    var ux = dx / d, uy = dy / d;
                    a.vx += ux * rf; a.vy += uy * rf;
                    b.vx -= ux * rf; b.vy -= uy * rf;
                  }
                }
                lnks.forEach(function (l) {
                  if (l.from === l.to) { return; }
                  var a = l.from, b = l.to;
                  var dx = (b.x + b.w / 2) - (a.x + a.w / 2);
                  var dy = (b.y + b.h / 2) - (a.y + a.h / 2);
                  var d = Math.sqrt(dx * dx + dy * dy) + 0.01;
                  var f = (d - ideal) * 0.01;
                  var ux = dx / d, uy = dy / d;
                  a.vx += ux * f; a.vy += uy * f;
                  b.vx -= ux * f; b.vy -= uy * f;
                });
                for (var k = 0; k < n; k++) {
                  var node = nodes[k];
                  node.x += clamp(node.vx, -60, 60) * cooling;
                  node.y += clamp(node.vy, -60, 60) * cooling;
                  node.vx *= 0.85; node.vy *= 0.85;
                }
                resolveCollisions(nodes, 30);
              }
            }

            function resolveCollisions(nodes, pad) {
              var n = nodes.length;
              for (var i = 0; i < n; i++) {
                var a = nodes[i];
                for (var j = i + 1; j < n; j++) {
                  var b = nodes[j];
                  var ox = Math.min(a.x + a.w + pad, b.x + b.w + pad) - Math.max(a.x, b.x);
                  var oy = Math.min(a.y + a.h + pad, b.y + b.h + pad) - Math.max(a.y, b.y);
                  if (ox > 0 && oy > 0) {
                    if (ox < oy) {
                      var sx = ox / 2;
                      if (a.x < b.x) { a.x -= sx; b.x += sx; } else { a.x += sx; b.x -= sx; }
                    } else {
                      var sy = oy / 2;
                      if (a.y < b.y) { a.y -= sy; b.y += sy; } else { a.y += sy; b.y -= sy; }
                    }
                  }
                }
              }
            }

            function bbox(nodes) {
              var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
              nodes.forEach(function (n) {
                if (n.x < minX) minX = n.x;
                if (n.y < minY) minY = n.y;
                if (n.x + n.w > maxX) maxX = n.x + n.w;
                if (n.y + n.h > maxY) maxY = n.y + n.h;
              });
              return { minX: minX, minY: minY, w: maxX - minX, h: maxY - minY };
            }

            // Shelf-pack components left-to-right, wrapping into rows.
            function packComponents(boxes, target) {
              var gap = 90, totalArea = 0, maxW = 0;
              boxes.forEach(function (bx) {
                totalArea += (bx.w + gap) * (bx.h + gap);
                if (bx.w > maxW) { maxW = bx.w; }
              });
              var rowWidth = Math.max(maxW, Math.sqrt(totalArea * target));
              var x = 0, y = 0, rowH = 0;
              boxes.forEach(function (bx) {
                if (x > 0 && x + bx.w > rowWidth) { x = 0; y += rowH + gap; rowH = 0; }
                var ox = x + 60, oy = y + 60;
                bx.comp.forEach(function (node) { node.x += ox; node.y += oy; });
                x += bx.w + gap;
                if (bx.h > rowH) { rowH = bx.h; }
              });
            }

            function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

            function place(node) {
              node.el.style.left = node.x + "px";
              node.el.style.top = node.y + "px";
            }

            // ---- Edge drawing ------------------------------------------------
            function anchor(node, rowName, towardX) {
              // Returns a point on the left or right edge of the card, at the
              // vertical centre of the given row (or the card centre).
              var cy;
              if (rowName && node.rows[rowName]) {
                cy = node.y + node.rows[rowName].offsetTop + node.rows[rowName].offsetHeight / 2;
              } else {
                cy = node.y + node.h / 2;
              }
              var left = node.x, right = node.x + node.w;
              var x = (towardX < node.x + node.w / 2) ? left : right;
              return { x: x, y: cy, side: (x === left ? -1 : 1) };
            }

            function unit(dx, dy) {
              var d = Math.sqrt(dx * dx + dy * dy);
              return d < 0.001 ? [0, 0] : [dx / d, dy / d];
            }

            // Orthogonal path with rounded corners through a list of points.
            function roundedPath(pts, r) {
              if (pts.length < 2) { return ""; }
              var d = "M " + pts[0][0] + " " + pts[0][1];
              for (var i = 1; i < pts.length - 1; i++) {
                var p0 = pts[i - 1], p1 = pts[i], p2 = pts[i + 1];
                var len1 = Math.hypot(p0[0] - p1[0], p0[1] - p1[1]);
                var len2 = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]);
                var rr = Math.min(r, len1 / 2, len2 / 2);
                if (rr < 0.5) { d += " L " + p1[0] + " " + p1[1]; continue; }
                var v1 = unit(p0[0] - p1[0], p0[1] - p1[1]);
                var v2 = unit(p2[0] - p1[0], p2[1] - p1[1]);
                d += " L " + (p1[0] + v1[0] * rr) + " " + (p1[1] + v1[1] * rr) +
                     " Q " + p1[0] + " " + p1[1] + " " +
                     (p1[0] + v2[0] * rr) + " " + (p1[1] + v2[1] * rr);
              }
              var last = pts[pts.length - 1];
              return d + " L " + last[0] + " " + last[1];
            }

            // Lines exit horizontally from the card side, then step through a
            // shared vertical channel — the dbdiagram.io connector style.
            function orthoPoints(a, b) {
              var stub = 18;
              var a1 = a.x + a.side * stub;
              var b1 = b.x + b.side * stub;
              var midX = (a1 + b1) / 2;
              return [[a.x, a.y], [a1, a.y], [midX, a.y], [midX, b.y], [b1, b.y], [b.x, b.y]];
            }

            // Crow's-foot ("many") or a single tick ("one") at a card-edge point.
            function markerPath(point, kind) {
              var s = point.side, x = point.x, y = point.y;
              if (kind === "many") {
                var base = x + s * 13;
                return "M " + base + " " + y + " L " + x + " " + (y - 5) +
                       " M " + base + " " + y + " L " + x + " " + y +
                       " M " + base + " " + y + " L " + x + " " + (y + 5);
              }
              var tx = x + s * 9;
              return "M " + tx + " " + (y - 5) + " L " + tx + " " + (y + 5);
            }

            function renderEdge(l) {
              var g = l.group;
              while (g.firstChild) { g.removeChild(g.firstChild); }
              var a = anchor(l.from, l.fkRow, l.to.x + l.to.w / 2);
              var b = anchor(l.to, l.pkRow, l.from.x + l.from.w / 2);

              var link = document.createElementNS(SVGNS, "path");
              link.setAttribute("class", "link");
              link.setAttribute("d", roundedPath(orthoPoints(a, b), 9));
              g.appendChild(link);

              [[a, l.card.from], [b, l.card.to]].forEach(function (pair) {
                var m = document.createElementNS(SVGNS, "path");
                m.setAttribute("class", "marker");
                m.setAttribute("d", markerPath(pair[0], pair[1]));
                g.appendChild(m);
              });
            }

            function drawEdges() {
              while (edges.firstChild) { edges.removeChild(edges.firstChild); }
              var bounds = worldBounds();
              edges.setAttribute("width", bounds.w);
              edges.setAttribute("height", bounds.h);
              links.forEach(function (l) {
                var g = document.createElementNS(SVGNS, "g");
                g.setAttribute("class", "edge");
                l.group = g;
                edges.appendChild(g);
                renderEdge(l);
              });
            }

            function redrawEdgesFor(node) {
              node.edges.forEach(renderEdge);
            }

            function worldBounds() {
              var w = 0, h = 0;
              order.forEach(function (n) {
                if (n.x + n.w > w) w = n.x + n.w;
                if (n.y + n.h > h) h = n.y + n.h;
              });
              return { w: w + 80, h: h + 80 };
            }

            // ---- Pan / zoom --------------------------------------------------
            var view = { x: 0, y: 0, scale: 1 };
            function applyView() {
              world.style.transform =
                "translate(" + view.x + "px," + view.y + "px) scale(" + view.scale + ")";
            }

            function fitView() {
              var b = worldBounds();
              var vw = viewport.clientWidth, vh = viewport.clientHeight;
              var s = Math.min(vw / b.w, vh / b.h);
              s = clamp(s, 0.05, 1);
              view.scale = s;
              view.x = (vw - b.w * s) / 2;
              view.y = (vh - b.h * s) / 2;
              applyView();
            }

            viewport.addEventListener("wheel", function (e) {
              e.preventDefault();
              var rect = viewport.getBoundingClientRect();
              var mx = e.clientX - rect.left, my = e.clientY - rect.top;
              var factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
              var ns = clamp(view.scale * factor, 0.05, 3);
              // Zoom toward cursor.
              view.x = mx - (mx - view.x) * (ns / view.scale);
              view.y = my - (my - view.y) * (ns / view.scale);
              view.scale = ns;
              applyView();
            }, { passive: false });

            // Pan vs card drag.
            var panning = false, dragNode = null, last = { x: 0, y: 0 };
            viewport.addEventListener("pointerdown", function (e) {
              var card = e.target.closest(".card");
              last.x = e.clientX; last.y = e.clientY;
              if (card && card._node) {
                dragNode = card._node;
                card.classList.add("dragging");
                highlight(dragNode, true);
              } else {
                panning = true;
                viewport.classList.add("panning");
              }
              viewport.setPointerCapture(e.pointerId);
            });
            viewport.addEventListener("pointermove", function (e) {
              if (!panning && !dragNode) { return; }
              var dx = e.clientX - last.x, dy = e.clientY - last.y;
              last.x = e.clientX; last.y = e.clientY;
              if (dragNode) {
                dragNode.x += dx / view.scale;
                dragNode.y += dy / view.scale;
                place(dragNode);
                redrawEdgesFor(dragNode);
              } else {
                view.x += dx; view.y += dy;
                applyView();
              }
            });
            function endPointer() {
              if (dragNode) {
                dragNode.el.classList.remove("dragging");
                highlight(dragNode, false);
              }
              dragNode = null;
              panning = false;
              viewport.classList.remove("panning");
            }
            viewport.addEventListener("pointerup", endPointer);
            viewport.addEventListener("pointercancel", endPointer);

            function highlight(node, on) {
              var related = {};
              related[node.name] = true;
              node.edges.forEach(function (l) {
                related[l.from.name] = true; related[l.to.name] = true;
                if (l.group) { l.group.classList.toggle("active", on); }
              });
              order.forEach(function (n) {
                n.el.classList.toggle("dim", on && !related[n.name]);
                n.el.classList.toggle("focus", on && n === node);
              });
            }

            // Tag cards with their node for hit-testing.
            order.forEach(function (n) { n.el._node = n; });

            // ---- Controls ----------------------------------------------------
            document.querySelector(".toolbar").addEventListener("click", function (e) {
              var action = e.target.getAttribute("data-action");
              if (action === "relayout") { layout(); }
              else if (action === "reset") { view.scale = 1; view.x = 60; view.y = 60; applyView(); }
              else if (action === "fit") { fitView(); }
            });

            layout();
          })();
          </script>
        </body>
      </html>
    HTML

    def initialize(diagram:, title:, notice: nil)
      @diagram = diagram
      @title = title
      @notice = notice
    end

    def call
      ERB.new(TEMPLATE).result(binding)
    end

    private

    attr_reader :diagram, :notice, :title

    def data_json
      # JSON is the escaping boundary; neutralise any "</script>" in the data.
      JSON.generate(diagram).gsub('</', '<\/')
    end
  end
end
