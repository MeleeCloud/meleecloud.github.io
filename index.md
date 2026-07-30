---
layout: default
title: Home
permalink: /
---

<!-- Build your homepage here in your own words. -->

## Recent entries

{% assign recent_entries = site.entries | reverse %}

{% for entry in recent_entries limit: 3 %}
<article class="entry-card">
  <h3>
    <a href="{{ entry.url | relative_url }}">{{ entry.title }}</a>
  </h3>

  {% if entry.media_type %}
  <p>{{ entry.media_type }}</p>
  {% endif %}
</article>
{% else %}
<p>No entries have been published yet.</p>
{% endfor %}
