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
(import [mpm.fs :as fs])
(import [mpmplay.player [Player]])
(import yaml)
(require [high.macros [*]])

(def *default-config* (dict :database "~/.mpm.d/database"))

(defn get-config [config-file]
  "Return config after reading it from given file. Create a file if none exits."
  (with [cf (open (fs.ensure-file config-file (yaml.dump *default-config*)))]
        (yaml.load cf)))

(defn cli []
  (let [args (docopt *doc* :version "mpm-play v0.1.0")
        config (get-config (get args "--config"))]
    (.start-server (Player config))))
