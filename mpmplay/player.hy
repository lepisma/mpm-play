;; Player

(import [mpm.db :as db])
(import pafy)
(import vlc)
(import subprocess)
(require [mpm.macros [*]])

(defn get-beets-file-url [beets-db beets-id]
  (let [res (beets-db.query (+ "SELECT path FROM items WHERE id = " (str beets-id)))
        file-url (get (first res) "path")]
    (+ "file://" (if (is (type file-url) bytes)
                   (.decode file-url "utf8")
                   file-url))))

(defn get-yt-stream-url [ytid]
  (let [pf (pafy.new ytid :basic False)
        audio (pf.getbestaudio)]
    audio.url))

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
    (setv self.vlc-instance (vlc.Instance))
    (setv self.media-player (self.vlc-instance.media-player-new)))

  (defn parse-mpm-url [self url]
    "Parse mpm url in a playable source"
    (let [[source-type id] (.split url ":")]
      (cond [(= source-type "yt") (get-yt-stream-url id)]
            [(= source-type "beets") (get-beets-file-url self.beets-db (int id))]
            [True (raise (NotImplementedError))])))

  (defn play [self song]
    "Play the given song"
    (let [murl (self.parse-mpm-url (get song "url"))
          media (self.vlc-instance.media-new murl)]
      (print (+ "Playing: " (get-song-identifier song)))
      ;; (self.media-player.set-media media)
      ;; (self.media-player.play)
      (subprocess.run ["mplayer" murl]))))
