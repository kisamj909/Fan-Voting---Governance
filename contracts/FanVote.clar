(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_INACTIVE (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INVALID_PROPOSAL_TYPE (err u104))
(define-constant ERR_INVALID_DURATION (err u105))
(define-constant ERR_PROPOSAL_ENDED (err u106))
(define-constant ERR_PROPOSAL_ACTIVE (err u107))
(define-constant ERR_INVALID_OPTION (err u108))

(define-constant PROPOSAL_TYPE_UNIFORM u1)
(define-constant PROPOSAL_TYPE_CHARITY u2)
(define-constant PROPOSAL_TYPE_EVENT u3)
(define-constant PROPOSAL_TYPE_GENERAL u4)

(define-constant MIN_VOTING_DURATION u144)
(define-constant MAX_VOTING_DURATION u4320)

(define-data-var proposal-counter uint u0)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var current-block-height uint u1)

(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: uint,
    creator: principal,
    start-block: uint,
    end-block: uint,
    total-votes: uint,
    status: uint
  }
)

(define-map proposal-options
  { proposal-id: uint, option-id: uint }
  {
    option-text: (string-ascii 200),
    vote-count: uint
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { option-id: uint, voted-at: uint }
)

(define-map voter-participation
  { voter: principal }
  { total-votes: uint, last-vote-block: uint }
)

(define-map proposal-results
  { proposal-id: uint }
  { winning-option: uint, total-participants: uint, finalized-at: uint }
)

(define-read-only (get-admin)
  (var-get admin)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-current-block)
  (var-get current-block-height)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-option (proposal-id uint) (option-id uint))
  (map-get? proposal-options { proposal-id: proposal-id, option-id: option-id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-voter-stats (voter principal))
  (map-get? voter-participation { voter: voter })
)

(define-read-only (get-proposal-result (proposal-id uint))
  (map-get? proposal-results { proposal-id: proposal-id })
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal
    (let ((current-block (var-get current-block-height)))
      (and 
        (>= current-block (get start-block proposal))
        (<= current-block (get end-block proposal))
        (is-eq (get status proposal) u1)
      )
    )
    false
  )
)

(define-read-only (has-user-voted (proposal-id uint) (user principal))
  (is-some (get-vote proposal-id user))
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal
    (let ((current-block (var-get current-block-height))
          (start-block (get start-block proposal))
          (end-block (get end-block proposal))
          (status (get status proposal)))
      (if (is-eq status u0)
        u0
        (if (< current-block start-block)
          u1
          (if (<= current-block end-block)
            u2
            u3
          )
        )
      )
    )
    u0
  )
)

(define-read-only (calculate-winning-option (proposal-id uint))
  (let ((option-1 (default-to { option-text: "", vote-count: u0 } 
                    (get-proposal-option proposal-id u1)))
        (option-2 (default-to { option-text: "", vote-count: u0 } 
                    (get-proposal-option proposal-id u2)))
        (option-3 (default-to { option-text: "", vote-count: u0 } 
                    (get-proposal-option proposal-id u3)))
        (option-4 (default-to { option-text: "", vote-count: u0 } 
                    (get-proposal-option proposal-id u4))))
    (let ((votes-1 (get vote-count option-1))
          (votes-2 (get vote-count option-2))
          (votes-3 (get vote-count option-3))
          (votes-4 (get vote-count option-4)))
      (if (and (>= votes-1 votes-2) (>= votes-1 votes-3) (>= votes-1 votes-4))
        u1
        (if (and (>= votes-2 votes-3) (>= votes-2 votes-4))
          u2
          (if (>= votes-3 votes-4)
            u3
            u4
          )
        )
      )
    )
  )
)

(define-private (is-valid-proposal-type (proposal-type uint))
  (or (is-eq proposal-type PROPOSAL_TYPE_UNIFORM)
      (is-eq proposal-type PROPOSAL_TYPE_CHARITY)
      (is-eq proposal-type PROPOSAL_TYPE_EVENT)
      (is-eq proposal-type PROPOSAL_TYPE_GENERAL))
)

(define-private (is-valid-duration (duration uint))
  (and (>= duration MIN_VOTING_DURATION) (<= duration MAX_VOTING_DURATION))
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (proposal-type uint)
    (duration uint)
    (option-1 (string-ascii 200))
    (option-2 (string-ascii 200))
    (option-3 (string-ascii 200))
    (option-4 (string-ascii 200)))
  (let ((proposal-id (+ (var-get proposal-counter) u1))
        (current-block (var-get current-block-height))
        (end-block (+ current-block duration)))
    (asserts! (is-valid-proposal-type proposal-type) ERR_INVALID_PROPOSAL_TYPE)
    (asserts! (is-valid-duration duration) ERR_INVALID_DURATION)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposal-type: proposal-type,
        creator: tx-sender,
        start-block: current-block,
        end-block: end-block,
        total-votes: u0,
        status: u1
      }
    )
    (map-set proposal-options 
      { proposal-id: proposal-id, option-id: u1 }
      { option-text: option-1, vote-count: u0 })
    (map-set proposal-options 
      { proposal-id: proposal-id, option-id: u2 }
      { option-text: option-2, vote-count: u0 })
    (map-set proposal-options 
      { proposal-id: proposal-id, option-id: u3 }
      { option-text: option-3, vote-count: u0 })
    (map-set proposal-options 
      { proposal-id: proposal-id, option-id: u4 }
      { option-text: option-4, vote-count: u0 })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (option-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block (var-get current-block-height))
        (option (unwrap! (get-proposal-option proposal-id option-id) ERR_INVALID_OPTION)))
    (asserts! (is-proposal-active proposal-id) ERR_PROPOSAL_INACTIVE)
    (asserts! (not (has-user-voted proposal-id tx-sender)) ERR_ALREADY_VOTED)
    (asserts! (and (>= option-id u1) (<= option-id u4)) ERR_INVALID_OPTION)
    
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { option-id: option-id, voted-at: current-block }
    )
    
    (map-set proposal-options
      { proposal-id: proposal-id, option-id: option-id }
      { 
        option-text: (get option-text option),
        vote-count: (+ (get vote-count option) u1)
      }
    )
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { total-votes: (+ (get total-votes proposal) u1) })
    )
    
    (let ((current-stats (default-to { total-votes: u0, last-vote-block: u0 }
                          (get-voter-stats tx-sender))))
      (map-set voter-participation
        { voter: tx-sender }
        {
          total-votes: (+ (get total-votes current-stats) u1),
          last-vote-block: current-block
        }
      )
    )
    
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block (var-get current-block-height)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> current-block (get end-block proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (is-eq (get status proposal) u1) ERR_PROPOSAL_INACTIVE)
    
    (let ((winning-option (calculate-winning-option proposal-id)))
      (map-set proposal-results
        { proposal-id: proposal-id }
        {
          winning-option: winning-option,
          total-participants: (get total-votes proposal),
          finalized-at: current-block
        }
      )
      
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { status: u2 })
      )
      
      (ok winning-option)
    )
  )
)

(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (var-get admin)) 
                  (is-eq tx-sender (get creator proposal))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) u1) ERR_PROPOSAL_INACTIVE)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { status: u0 })
    )
    
    (ok true)
  )
)

(define-public (extend-proposal (proposal-id uint) (additional-blocks uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-proposal-active proposal-id) ERR_PROPOSAL_INACTIVE)
    (asserts! (<= additional-blocks u1440) ERR_INVALID_DURATION)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        end-block: (+ (get end-block proposal) additional-blocks)
      })
    )
    
    (ok true)
  )
)