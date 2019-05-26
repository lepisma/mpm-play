(setv *doc* "mpm-scrobble

Usage:
  mpm-scrobble [--config=<CFG>] [--log=<LOG>] [--scrobbled-at=<FILE>] [--lfm-creds=<JSON>]
  mpm-scrobble -h | --help
  mpm-scrobble -v | --version

Options:
  -h, --help             Show this screen.
  -v, --version          Show version.
  --config=<CFG>         Path to config file [default: ~/.mpm.d/config]
  --log=<LOG>            Path to play log file [default: ~/.mpm.d/play-log]
  --scrobbled-at=<FILE>  Path to scrobbled at file [default: ~/.mpm.d/scrobbled-at]
  --lfm-creds=<JSON>     Path to lastfm creds file [default: ~/.mpm.d/last-fm.json]")

(import [pylast [LastFMNetwork]])
(import [docopt [docopt]])
(import yaml)
(import json)
(import [mpmplay [--version--]])
(import [mpm.mpm [Mpm]])
(import [mpm.db :as db])
(import [high.utils [*]])
(import [time [time]])
(require [high.macros [*]])


(defn read-log [file-name]
  (emap (fn [line] (emap int (.split line ",")))
        (with-fp file-name
          (efilter (fn [line] (> (len line) 0)) (.split (fp.read) "\n")))))

(defn item-present? [log-entry mpm-instance]
  "Check if the item in entry is present in db"
  (db.song-present? mpm-instance.database :id (second log-entry)))

(defn get-item [log-entry mpm-instance]
  "Get the item represented in the entry"
  (let [song (db.get-song mpm-instance.database (second log-entry))]
    {"artist" (get song "artist")
     "title" (get song "title")
     "album" (get song "album")
     "timestamp" (first log-entry)}))

(defn filter-entries [log-entries timestamp mpm-instance]
  "Remove entries older than the timestamp"
  (efilter (fn [entry] (> (get (get-item entry mpm-instance) "timestamp") timestamp))
           (efilter (fn [it] (item-present? it mpm-instance)) log-entries)))

(defn scrobble [log-entries lastfm-network mpm-instance]
  (let [items (emap (fn [it] (get-item it mpm-instance)) log-entries)]
    (if (= (len items) 0)
        (print "Nothing to do")
        (do (print (+ "Scrobbling " (str (len items)) " items"))
            (lastfm-network.scrobble-many items)))))

(defn update-last-scrobble [file-name]
  (with [fp (open file-name "w")]
    (fp.write (str (int (time))))))

(defn cli []
  (let [args (docopt *doc* :version --version--)
        mpm-instance (Mpm (with-fp #p(get args "--config") (yaml.load fp)))
        lastfm-config (with-fp #p(get args "--lfm-creds") (json.load fp))
        log-entries (read-log #p(get args "--log"))
        scrobbled-at-file #p(get args "--scrobbled-at")
        last-scrobble (with-fp (ensure-file scrobbled-at-file "0") (int (fp.read)))
        lastfm-network (apply LastFMNetwork [] lastfm-config)]
    (scrobble (filter-entries log-entries last-scrobble mpm-instance) lastfm-network mpm-instance)
    (update-last-scrobble scrobbled-at-file)
    (exit 0)))
