;; Player

(import [mpm.mpm [Mpm]])
(import [mpm.db :as db])
(import [mpmplay [vlc]])
(import [mpmplay.cache [Ytcache]])
(import [sanic [Sanic]])
(import [sanic.response [json :as sanic-json]])

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

(defmacro/g! route [r-path func-body]
  "Setup route mapping"
  `(with-decorator (self.app.route ~r-path)
     (defn ~g!route-func [req] ~func-body)))

(defclass Player []
  (defn --init-- [self config]
    (setv self.mpm-instance (Mpm config))
    (setv self.database self.mpm-instance.database)
    (setv self.config (get config "player"))
    (setv self.port (get self.config "port"))
    (setv self.yt-cache (Ytcache #p(get self.config "cache")))
    (setv self.beets-db (get-beets-db self.database))
    (setv self.playlist [])
    (setv self.repeat False)
    (setv self.random False))

  (defn parse-mpm-url [self song]
    "Parse song in a playable url"
    (let [url (get song "url")
          [source-type id] (.split url ":")]
      (cond [(= source-type "yt") (self.yt-cache.get-playable-url song)]
            [(= source-type "beets") (get-beets-file-url self.beets-db (int id))]
            [True (rase (NotImplementedError))])))

  (defn clear-playlist [self]
    (setv self.playlist []))

  (defn add-songs [self song-ids]
    (+= self.playlist song-ids))

  (defn stop-song [self]
    "Stop the player"
    (subprocess.call ["killall" "mplayer"]))

  (defn play-song [self song-id]
    "Play the given song"
    (let [song (db.get-song self.database song-id)
          murl (self.parse-mpm-url song)]
      (print (+ "Playing: " (get-song-identifier song)))
      (subprocess.Popen ["mplayer" murl])))

  (defn start-server [self]
    "Start music server"
    (setv self.app (Sanic))

    (route "/"
           (sanic-json "Hello World"))

    (route "/status"
           (sanic-json "ok"))

    (route "/clear"
           (do
            (self.clear-playlist)
            (sanic-json "ok")))

    (route "/add"
           (let [song-ids (list (map int (.split (get req.raw_args "ids") ",")))]
             (self.add-songs song-ids)
             (sanic-json "ok")))

    (route "/play"
           (let [song-id (int (get req.raw_args "id"))]
             (self.stop-song)
             (self.play-song song-id)
             (sanic-json "ok")))

    (self.app.run :host "127.0.0.1" :port self.port)))
