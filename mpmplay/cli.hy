(setv *doc* "mpm-play

Usage:
  mpm-play [--config=<CFG>]

  mpm-play -h | --help
  mpm-play -v | --version

Options:
  -h, --help       Show this screen.
  -v, --version    Show version.
  --config=<CFG>   Path to config file [default: ~/.mpm.d/config]")

(import [docopt [docopt]])
(import [mpmplay.server [Server]])
(import [mpmplay [--version--]])
(import yaml)
(require [high.macros [*]])

(defn get-config [config-file]
  "Return config after reading it from given file."
  (with [cf (open #pconfig-file)]
    (yaml.load cf)))

(defn cli []
  (let [args (docopt *doc* :version --version--)
        config (get-config (get args "--config"))]
    (.start (Server config))))
