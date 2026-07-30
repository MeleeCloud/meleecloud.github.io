# meleecloud.github.io

Documenting all types of media that I've enjoyed throughout the years.

## Adding a library entry

1. Add its metadata to `_data/library.yml`.
2. Create `_entries/entry-id.md` with matching front matter:

   ```yaml
   ---
   entry_id: entry-id
   ---
   ```

3. Write the entry below the front matter.

The `entry_id` links the catalog record, its writing, and any topic pages.
Use lowercase words separated by hyphens and keep it unchanged.

The Library's featured order uses the catalog's `order` values. Leave gaps
such as 10, 20, and 30 so entries can be inserted later.

## Decap CMS

The editor is available at `/admin/` after Netlify Identity and Git Gateway
are connected. Use:

- **Library Catalog** to manage metadata for every game in one screen.
- **Entry Writing** for each game's main page.
- **Entry Topics** for subtopic pages.

When creating an entry, add it to both Library Catalog and Entry Writing with
the exact same `entry_id`.
