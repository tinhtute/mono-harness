/* OpenPI Blueprint Design System · js/main.js
 * 99.99% faithful implementation of OpenPI interactive behaviors:
 * scroll progress, reveal observer, copy button, interactive terminal, nav tracking
 */

(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* 1. Scroll Progress Bar */
  var bar = document.getElementById("progress");
  if (bar) {
    var updateProgress = function () {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + "%";
    };
    window.addEventListener("scroll", updateProgress, { passive: true });
    updateProgress();
  }

  /* 2. Scroll Reveal on Intersection */
  var reveals = document.querySelectorAll(".reveal");
  if (reveals.length > 0) {
    if (reduced || !("IntersectionObserver" in window)) {
      reveals.forEach(function (el) { el.classList.add("in"); });
    } else {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        });
      }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });
      reveals.forEach(function (el) { io.observe(el); });
    }
  }

  /* 3. Terminal Typewriter Demo */
  var TERM_LINES = [
    { cls: "t-cmd", text: "zharness install" },
    { cls: "t-ok", text: "✓ scaffolded docs/ · committed markdown is truth" },
    { cls: "t-cmd", text: "npx skills add tinhtute/monoharness" },
    { cls: "t-out", text: "● 17 skills mounted · zero resident daemons" },
    { cls: "t-out", text: "● fail-closed guards active · fixture suite green" }
  ];

  var termTimer = null;
  function resetTerm() {
    var body = document.getElementById("term-body");
    if (!body) return;
    if (termTimer) { clearTimeout(termTimer); termTimer = null; }

    body.innerHTML = "";
    if (reduced) {
      for (var i = 0; i < TERM_LINES.length; i++) {
        var d = document.createElement("div");
        d.className = TERM_LINES[i].cls;
        d.textContent = TERM_LINES[i].text;
        body.appendChild(d);
      }
      return;
    }

    var li = 0;
    function nextLine() {
      if (li >= TERM_LINES.length) {
        termTimer = setTimeout(resetTerm, 7000);
        return;
      }
      var l = TERM_LINES[li++];
      var d = document.createElement("div");
      d.className = l.cls;
      body.appendChild(d);

      if (l.cls !== "t-cmd") {
        d.textContent = l.text;
        termTimer = setTimeout(nextLine, 520);
        return;
      }

      var ci = 0;
      var caret = document.createElement("span");
      caret.className = "caret";
      d.appendChild(caret);

      (function typeChar() {
        if (ci < l.text.length) {
          d.insertBefore(document.createTextNode(l.text[ci++]), caret);
          termTimer = setTimeout(typeChar, 16 + Math.random() * 28);
        } else {
          caret.remove();
          termTimer = setTimeout(nextLine, 480);
        }
      })();
    }
    termTimer = setTimeout(nextLine, 800);
  }
  resetTerm();

  /* 4. Copy to Clipboard */
  function bindCopy(btn) {
    if (!btn) return;
    btn.addEventListener("click", async function () {
      var cmd = btn.getAttribute("data-cmd") || "zharness install";
      var original = btn.textContent;
      try {
        await navigator.clipboard.writeText(cmd);
      } catch (e) {
        var ta = document.createElement("textarea");
        ta.value = cmd;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      }
      btn.textContent = "COPIED";
      setTimeout(function () { btn.textContent = original; }, 1600);
    });
  }
  document.querySelectorAll("[data-copy], .copy-btn, #copy-btn").forEach(bindCopy);

  /* 5. Duplicate Marquee Track for Seamless Loop */
  var track = document.getElementById("marquee-track");
  if (track && track.children.length > 0) {
    track.innerHTML += track.innerHTML;
  }
  var heroTrack = document.getElementById("hero-marquee-track");
  if (heroTrack && heroTrack.children.length > 0) {
    heroTrack.innerHTML += heroTrack.innerHTML;
  }

  /* 6. Active Nav Link Detection */
  var path = location.pathname.replace(/\/+$/, "");
  var here = (path.split("/").pop() || "index.html") || "index.html";

  document.querySelectorAll(".nav-links a, .mast-nav a").forEach(function (link) {
    var href = link.getAttribute("href") || "";
    var target = href.replace(/\/+$/, "").split("/").pop() || "index.html";
    if (target === here || (here === "" && target === "index.html")) {
      link.setAttribute("aria-current", "page");
      link.classList.add("active");
      link.classList.add("nav-link-active");
    } else {
      link.removeAttribute("aria-current");
      link.classList.remove("active");
      link.classList.remove("nav-link-active");
    }
  });

  /* 7. Smooth In-Page Anchor Scrolling */
  if (!reduced) {
    document.querySelectorAll('a[href^="#"]:not([href="#"])').forEach(function (anchor) {
      anchor.addEventListener("click", function (event) {
        var id = anchor.getAttribute("href").slice(1);
        if (!id) return;
        var target = document.getElementById(id);
        if (target) {
          event.preventDefault();
          target.scrollIntoView({ behavior: "smooth", block: "start" });
          history.replaceState(null, "", "#" + id);
        }
      });
    });
  }
})();
