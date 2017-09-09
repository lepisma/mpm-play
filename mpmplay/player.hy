;; Player

(import [mpm.db :as db])
(import [mpmplay [vlc]])
(import [mpmplay.cache [Ytcache]])
(import subprocess)
(require [high.macros [*]])

(defn get-beets-file-url [beets-db beets-id]
  (let [res (beets-db.query (+ "SELECT path FROM items WHERE id = " (str beets-id)))
        file-url (get (first res) "path")]
    (+ "file://" (if (is (type file-url) bytes)
                   (.decode file-url "utf8")
                   file-url))))

(defn get-beets-db [config-db]
  "Return connection to beets db from config-db"
  (let [sources (get config-db "sources")]
    (db.get-dataset-conn (get (sources.find-one :resolver "beets") "url"))))

(defn get-song-identifier [song]
  (let [title (get song "title")
        artist (get song "artist")]
    (if title (+ title " - " artist)
        (get song "url"))))

(defclass Player []
  (defn --init-- [self config]
    (setv self.config config)
    (setv self.database (db.get-dataset-conn (get self.config "database")))
    (setv self.beets-db (get-beets-db self.database))
    (setv self.yt-cache (Ytcache #p (get (get self.config "player") "cache")))
    (setv self.playlist [])
    (setv self.repeat False)
    (setv self.random False))

  (defn parse-mpm-url [self song]
    "Parse song in a playable url"
    (let [url (get song "url")
          [source-type id] (.split url ":")]
      (cond [(= source-type "yt") (self.yt-cache.get-playable-url song)]
            [(= source-type "beets") (get-beets-file-url self.beets-db (int id))]
            [True (raise (NotImplementedError))])))

  (defn play [self song]
    "Play the given song"
    (let [murl (self.parse-mpm-url song)]
      (print (+ "Playing: " (get-song-identifier song)))
      (subprocess.run ["mplayer" murl]))))
