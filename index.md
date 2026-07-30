---
layout: default
title: Home
permalink: /
---

<!-- Build your homepage here in your own words. -->

## Recent entries

{% assign recent_entries = site.entries | reverse %}

{% for entry in recent_entries limit: 3 %}
{% assign metadata = site.data.library.entries
  | where: "entry_id", entry.entry_id
  | first
%}
<article class="entry-card">
  <h3>
    <a href="{{ entry.url | relative_url }}">
      {{ metadata.title | default: entry.entry_id }}
    </a>
  </h3>

  {% if metadata.media_type %}
  <p>{{ metadata.media_type }}</p>
  {% endif %}
</article>
{% else %}
<p>No entries have been published yet.</p>
{% endfor %}
