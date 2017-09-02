(setv *doc* "mpm-play

Usage:
  mpm-play <id> [--config=<CFG>]

  mpm-play -h | --help
  mpm-play -v | --version

Options:
  -h, --help       Show this screen.
  -v, --version    Show version.
  --config=<CFG>   Path to config file [default: ~/.mpm.d/config]")

(import [docopt [docopt]])
(import [mpm.mpm [Mpm]])
(import [mpm.fs :as fs])
(import [mpm.db :as db])
(import [mpmplay.player [Player]])
(import yaml)
(require [mpm.macros [*]])

(def *default-config* (dict :database "~/.mpm.d/database"))

(defn get-config [config-file]
  "Return config after reading it from given file. Create a file if none exits."
  (with [cf (open (fs.ensure-file config-file (yaml.dump *default-config*)))]
        (yaml.load cf)))

(defn cli []
  (let [args (docopt *doc* :version "mpm-play v0.1.0")
        config (get-config (get args "--config"))
        mpm-instance (Mpm config)
        player (Player config)
        song-id (int (get args "<id>"))]
    (player.play (db.get-song mpm-instance.database song-id))))
