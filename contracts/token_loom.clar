;; TokenLoom - NFT-based story arc platform
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-chapter-already-linked (err u103))
(define-constant err-content-too-long (err u104))
(define-constant err-invalid-operation (err u105))
(define-constant err-contract-paused (err u106))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map chapters
    uint 
    {
        title: (string-ascii 100),
        content: (string-utf8 1000),
        author: principal,
        next-chapter: (optional uint),
        version: uint
    }
)

(define-map story-arcs 
    uint 
    {
        title: (string-ascii 100),
        first-chapter: uint,
        contributors: (list 10 principal),
        metadata: (optional (string-utf8 500))
    }
)

;; NFT Setup
(define-non-fungible-token chapter uint)

;; Admin Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (var-set contract-paused paused))
    )
)

;; Mint new chapter
(define-public (mint-chapter (title (string-ascii 100)) (content (string-utf8 1000)))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (asserts! (<= (len content) u1000) (err err-content-too-long))
        (let
            (
                (token-id (+ (var-get last-token-id) u1))
            )
            (try! (nft-mint? chapter token-id tx-sender))
            (map-set chapters token-id {
                title: title,
                content: content,
                author: tx-sender,
                next-chapter: none,
                version: u1
            })
            (var-set last-token-id token-id)
            (print {event: "chapter-minted", token-id: token-id, author: tx-sender})
            (ok token-id)
        )
    )
)

;; Link chapters
(define-public (link-chapters (chapter-id uint) (next-chapter-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (let
            (
                (chapter (unwrap! (map-get? chapters chapter-id) (err err-invalid-token)))
            )
            (asserts! (is-eq tx-sender (get author chapter)) (err err-not-token-owner))
            (asserts! (is-none (get next-chapter chapter)) (err err-chapter-already-linked))
            (map-set chapters chapter-id (merge chapter {
                next-chapter: (some next-chapter-id),
                version: (+ (get version chapter) u1)
            }))
            (print {event: "chapters-linked", chapter-id: chapter-id, next-chapter-id: next-chapter-id})
            (ok true)
        )
    )
)

;; Unlink chapters
(define-public (unlink-chapters (chapter-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (let
            (
                (chapter (unwrap! (map-get? chapters chapter-id) (err err-invalid-token)))
            )
            (asserts! (is-eq tx-sender (get author chapter)) (err err-not-token-owner))
            (asserts! (is-some (get next-chapter chapter)) (err err-invalid-operation))
            (map-set chapters chapter-id (merge chapter {
                next-chapter: none,
                version: (+ (get version chapter) u1)
            }))
            (print {event: "chapters-unlinked", chapter-id: chapter-id})
            (ok true)
        )
    )
)

;; Create story arc
(define-public (create-story-arc (title (string-ascii 100)) (first-chapter uint) (metadata (optional (string-utf8 500))))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (let
            (
                (arc-id (+ (var-get last-token-id) u1))
            )
            (try! (nft-mint? chapter arc-id tx-sender))
            (map-set story-arcs arc-id {
                title: title,
                first-chapter: first-chapter,
                contributors: (list tx-sender),
                metadata: metadata
            })
            (var-set last-token-id arc-id)
            (print {event: "story-arc-created", arc-id: arc-id, creator: tx-sender})
            (ok arc-id)
        )
    )
)

;; Update story arc metadata
(define-public (update-story-arc-metadata (arc-id uint) (metadata (optional (string-utf8 500))))
    (let
        (
            (arc (unwrap! (map-get? story-arcs arc-id) (err err-invalid-token)))
        )
        (asserts! (is-eq tx-sender (get author (unwrap! (map-get? chapters (get first-chapter arc)) (err err-invalid-token)))) (err err-not-token-owner))
        (map-set story-arcs arc-id (merge arc {metadata: metadata}))
        (print {event: "story-arc-updated", arc-id: arc-id})
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-chapter (chapter-id uint))
    (map-get? chapters chapter-id)
)

(define-read-only (get-story-arc (arc-id uint))
    (map-get? story-arcs arc-id)
)

;; NFT trait implementation
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err err-not-token-owner))
        (nft-transfer? chapter token-id sender recipient)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? chapter token-id))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)
