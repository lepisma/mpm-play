;; Youtube caching module

(import pafy)
(import os)
(import [os.path :as path])
(import [high.utils [*]])
(require [high.macros [*]])
(import requests)
(import [eep [Searcher]])

(defn search-yt [search-term]
  "Search for term in youtube and return first youtube url"
  (let [params (dict :search_query search-term)
        res (requests.get "https://youtube.com/results" :params params)
        es (Searcher res.text)]
       (es.search-forward "watch?v=")
       (es.jump 11)
       (+ "https://youtube.com/" (es.get-sub))))

(defn first-hit-stream [song]
  "Return a stream using the first hit data"
  (let [yturl (search-yt (+ (get song "title") " " (get song "artist")))]
       (.getbestaudio (pafy.new :url yturl :basic False))))

(defclass Ytcache []
  "Cache youtube songs in a local directory"

  (defn --init-- [self cache-path]
    (setv self.cache-path cache-path)
    (ensure-dir cache-path)
    (self.init-listing))

  (defn init-listing [self]
    (let [files (os.listdir self.cache-path)]
         (setv self.cache-list files)))

  (defn save-in-cache [self stream file-name]
    "Download file in cache. Ignoring limit as of now."
    (let [file-path (path.join self.cache-path file-name)]
         (thread-run
           (.download stream
                      :quiet True
                      :filepath file-path))
         (self.cache-list.append file-name)))

  (defn get-playable-url [self song]
    "Return playable url. If the url is not of youtube type, then use a first hit url"
    (let [song-id (str (get song "id"))
          url-splits (.split (get song "url") ":")
          url-type (first url-splits)
          url-id (second url-splits)]
         (if (in song-id self.cache-list)
             (path.join self.cache-path song-id)
             (let [stream (if (= url-type "yt")
                              (.getbestaudio (pafy.new url-id :basic False))
                              (first-hit-stream song))]
                  ;; Start thread for downloading song and return the stream url
                  (self.save-in-cache stream song-id)
                  stream.url)))))
