# Non primary disk setup (npdisksetup)

Utility for

- Starting crypto disks and mounting them.
- Mounting non crypto disks.
- Unmounting non crypto disks.
- Unmounting and stoping crypto disks.

## Usage

```txt
usage: npdisksetup.py [-h] [-f FILE] {start,stop} [target [target ...]]

positional arguments:
  {start,stop}          The command to perform
  target                The target id found in the setupcfg file to process.
                        Default is "all".

optional arguments:
  -h, --help            show this help message and exit
  -f FILE, --file FILE  Path to a setupcfg file to use instead of the default.
```

The default _setupcfg_ location is `/etc/npdisksetup/setupcfg.yml`

## setupcfg file

The _setupcfg_ file is written in [YAML](https://yaml.org). At start, the
default or passed in _setupcfg_ file is read in its entirity. A single file can
have many documents, separated by a single line containing `---`, like so

```yaml
# document 1
---
# document 2
---
# document 3
---
# you get the idea?
```

Each document has 5 elements: `id`, `crypt`, `mount`, `options`, and `targets`.

### The `id` element

Each document is stored in a dictionary to be referenced later, maybe. The key
used for the document is defined by the `id` element. Because the value for `id`
is used as a dictionary key, each `id` value in a document must be unique.

```yaml
id: disk1
# rest of document

---
id: disk2
# rest of document
```

#### The "all" `id`

If you run _npdisksetup_ without providing any targets, the utility will search
the _setupcfg_ for a document with an `id` value of "all". The assumption is
that there will always be an "all" entry that contains a `targets` element. You
can override this behaviour by providing your own "all" document that excludes
the `targets` element and provide your own definition of other elements or not,
leaving the document empty.

### The `crypt` element

```yaml
id: disk1
crypt:
    name: disk1crypt

---
id: disk2
crypt:
    device: /dev/sdc1
    name: disk2crypt
```
