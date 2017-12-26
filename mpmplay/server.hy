;; Player

(import [mpm.mpm [Mpm]])
(import [mpm.db :as db])
(import [mpmplay.cache [Ytcache]])
(import [sanic [Sanic]])
(import [mplayer [Player]])
(import [sanic.response [json :as sanic-json]])
(import [high.utils [*]])
(import [threading [Lock Thread]])
(import [time [sleep]])
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

(defmacro/g! route [r-path &rest func-body]
  "Setup route mapping"
  `(with-decorator (self.app.route ~r-path :methods ["POST" "GET"])
     (defn ~g!route-func [req] (do ~@func-body))))

(defclass Server []
  (defn --init-- [self config]
    (setv mpm-instance (Mpm config))
    (setv self.database mpm-instance.database)
    (setv self.config (get config "player"))
    (setv self.port (get self.config "port"))
    (setv self.yt-cache (Ytcache #p(get self.config "cache")))
    (setv self.beets-db (get-beets-db self.database))
    (setv self.playlist [])
    (setv self.current -1)
    (setv self.lock (Lock))
    (setv self.should-play False) ; Internal flag to check in loop
    (setv self.mplayer-instance (Player :args ["-cache" 10000]))
    (setv self.loop (Thread :target self.p-loop))
    (self.loop.start))

  (defn get-state [self]
    "Return current state of the player. Following states are possible
- done    : done with playing a song
- started : just started, no files loaded
- paused  : song is loaded and paused
- playing : song is loaded and is getting played"
    (if (is self.mplayer-instance.percent-pos None)
        (if self.mplayer-instance.paused "done" "started")
        (if self.mplayer-instance.paused "paused" "playing")))

  (defn p-loop [self]
    (while True
      (sleep 0.5)
      (with [self.lock]
        (let [state (self.get-state)]
             (cond  [(and self.should-play (= state "paused")) (self.play)]
                    [(and self.should-play (= state "done")) (self.next-song)])))))

  (defn parse-mpm-url [self song]
    "Parse song in a playable url"
    (let [url (get song "url")
          [source-type id] (.split url ":")]
         (cond [(= source-type "yt") (self.yt-cache.get-playable-url song)]
               [(= source-type "beets") (get-beets-file-url self.beets-db (int id))]
               [True (raise (NotImplementedError))])))

  (defn clear-playlist [self]
    (setv self.playlist [])
    (setv self.current -1))

  (defn add-songs [self song-ids]
    (print (+ "Adding " (str (len song-ids)) " songs"))
    (+= self.playlist (emap (fn [i] (db.get-song self.database i)) song-ids)))

  (defn play [self]
    (if (= (self.get-state) "paused") (self.mplayer-instance.pause))
    (setv self.should-play True))

  (defn pause [self]
    (if (= (self.get-state) "playing") (self.mplayer-instance.pause))
    (setv self.should-play False))

  (defn toggle [self]
    (if (not self.should-play) (self.play) (self.pause)))

  (defn play-current [self]
    "Play the current song"
    (let [song (nth self.playlist self.current)
          murl (self.parse-mpm-url song)]
         (print (+ "Playing: " (get-song-identifier song)))
         (self.mplayer-instance.loadfile murl)
         (setv self.should-play True)))

  (defn get-current-song [self]
    "Return current song info"
    (nth self.playlist self.current))

  (defn prev-song [self]
    "Go back to prev song"
    (if (= self.current 0)
        (setv self.current (- (len self.playlist) 1))
        (-- self.current))
    (self.play-current))

  (defn next-song [self]
    "Next song"
    (if (= self.current (- (len self.playlist) 1))
        (setv self.current 0)
        (++ self.current))
    (self.play-current))

  (defn start [self]
    "Start music server"
    (setv self.app (Sanic))

    (route "/"
           (sanic-json "Hello World"))

    (route "/current"
           (with [self.lock]
             (if (>= self.current 0)
                 (sanic-json (self.get-current-song))
                 (sanic-json "NA"))))

    (route "/next"
           (with [self.lock]
             (if (!= (len self.playlist) 0)
                 (do (self.next-song)
                     (sanic-json "ok"))
                 (sanic-json "NA"))))

    (route "/prev"
           (with [self.lock]
             (if (!= (len self.playlist) 0)
                 (do (self.prev-song)
                     (sanic-json "ok"))
                 (sanic-json "NA"))))

    (route "/clear"
           (with [self.lock]
             (self.clear-playlist)
             (sanic-json "ok")))

    (route "/add"
           (with [self.lock]
             (let [id-str (first (get req.form "ids"))
                   ids (emap int (.split id-str ","))]
                  (self.add-songs ids)
                  (sanic-json "ok"))))

    (route "/toggle"
           (with [self.lock]
             (self.toggle)
             (sanic-json "ok")))

    (self.app.run :host "127.0.0.1" :port self.port)))
