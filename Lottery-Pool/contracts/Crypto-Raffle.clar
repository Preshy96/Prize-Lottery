;; Decentralized Lottery Pool Smart Contract
;; A fair and transparent lottery system that allows users to purchase tickets,
;; participate in draws, and claim winnings in a decentralized manner.
;; Features include configurable ticket prices, multiple winners per draw,
;; organizer fees, withdrawal periods, automatic prize distribution, and history tracking.

;; Error Constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-LOTTERY-NOT-ACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-TICKET-PRICE (err u104))
(define-constant ERR-NO-WINNERS-AVAILABLE (err u105))
(define-constant ERR-NO-TICKETS-OWNED (err u106))
(define-constant ERR-WITHDRAWAL-DEADLINE-PASSED (err u107))
(define-constant ERR-LOTTERY-STILL-RUNNING (err u108))
(define-constant ERR-WINNERS-ALREADY-DETERMINED (err u109))
(define-constant ERR-INVALID-LOTTERY-DURATION (err u110))
(define-constant ERR-INVALID-WITHDRAWAL-DURATION (err u111))
(define-constant ERR-WINNER-ID-NOT-FOUND (err u112))
(define-constant ERR-PRIZES-ALREADY-DISTRIBUTED (err u113))
(define-constant ERR-WINNERS-NOT-DETERMINED (err u114))
(define-constant ERR-LOTTERY-ROUND-NOT-FOUND (err u115))

;; Contract Configuration
(define-constant contract-administrator tx-sender)
(define-constant maximum-organizer-fee-rate u20)
(define-constant default-ticket-price u1000000)
(define-constant default-organizer-fee-rate u5)

;; Lottery State Variables
(define-data-var lottery-is-running bool false)
(define-data-var ticket-price-in-microstx uint default-ticket-price)
(define-data-var total-prize-pool uint u0)
(define-data-var tickets-sold-count uint u0)
(define-data-var maximum-winner-count uint u1)
(define-data-var lottery-closing-block uint u0)
(define-data-var withdrawal-deadline-block uint u0)
(define-data-var organizer-fee-rate uint default-organizer-fee-rate)
(define-data-var individual-winner-prize uint u0)
(define-data-var winners-have-been-selected bool false)
(define-data-var prizes-distributed bool false)
(define-data-var current-lottery-round uint u0)
(define-data-var total-lotteries-completed uint u0)

;; Data Storage Maps
(define-map participant-ticket-registry {ticket-number: uint} {participant-address: principal})
(define-map participant-ticket-balance principal uint)
(define-map lottery-winner-registry {winner-position: uint} {winner-address: principal, prize-claimed: bool})

;; History and Analytics Maps
(define-map lottery-history-records 
  {round-number: uint} 
  {start-block: uint, 
   end-block: uint, 
   ticket-price: uint, 
   total-tickets: uint, 
   total-prize-pool: uint, 
   winner-count: uint, 
   prize-per-winner: uint, 
   organizer-fee: uint,
   completion-timestamp: uint})

(define-map round-winner-history 
  {round-number: uint, winner-position: uint} 
  {winner-address: principal, prize-amount: uint})

(define-map participant-history 
  principal 
  {total-tickets-purchased: uint, 
   total-amount-spent: uint, 
   total-winnings: uint, 
   rounds-participated: uint, 
   rounds-won: uint})

(define-map participant-round-participation 
  {participant: principal, round-number: uint} 
  {tickets-bought: uint, amount-spent: uint, winnings: uint})

;; Authorization Validation
(define-private (validate-contract-administrator)
  (is-eq tx-sender contract-administrator))

;; Lottery State Validation
(define-private (ensure-lottery-is-active)
  (if (var-get lottery-is-running)
    (ok true)
    ERR-LOTTERY-NOT-ACTIVE))

;; Financial Validation
(define-private (verify-sufficient-balance (required-amount uint))
  (if (>= (stx-get-balance tx-sender) required-amount)
    (ok true)
    ERR-INSUFFICIENT-FUNDS))

;; Winner Selection Algorithm
(define-private (generate-winning-ticket-number (randomization-seed uint) (selection-index uint))
  (mod (+ randomization-seed selection-index) (var-get tickets-sold-count)))

;; Prize Distribution
(define-private (transfer-winnings-to-recipient (recipient-address principal) (prize-amount uint))
  (as-contract (stx-transfer? prize-amount tx-sender recipient-address)))

;; Fee Calculation
(define-private (compute-organizer-commission (total-pool-amount uint))
  (/ (* total-pool-amount (var-get organizer-fee-rate)) u100))

;; Helper Functions for History Tracking
(define-private (update-participant-history-on-purchase (participant principal) (ticket-cost uint) (round uint))
  (let ((current-stats (default-to {total-tickets-purchased: u0, total-amount-spent: u0, total-winnings: u0, rounds-participated: u0, rounds-won: u0} 
                                   (map-get? participant-history participant)))
        (round-stats (default-to {tickets-bought: u0, amount-spent: u0, winnings: u0}
                                 (map-get? participant-round-participation {participant: participant, round-number: round}))))
    (begin
      ;; Update overall participant history
      (map-set participant-history participant
        {total-tickets-purchased: (+ (get total-tickets-purchased current-stats) u1),
         total-amount-spent: (+ (get total-amount-spent current-stats) ticket-cost),
         total-winnings: (get total-winnings current-stats),
         rounds-participated: (if (is-eq (get tickets-bought round-stats) u0) 
                                (+ (get rounds-participated current-stats) u1) 
                                (get rounds-participated current-stats)),
         rounds-won: (get rounds-won current-stats)})
      
      ;; Update round-specific participation
      (map-set participant-round-participation {participant: participant, round-number: round}
        {tickets-bought: (+ (get tickets-bought round-stats) u1),
         amount-spent: (+ (get amount-spent round-stats) ticket-cost),
         winnings: (get winnings round-stats)}))))

(define-private (update-participant-history-on-win (participant principal) (prize-amount uint))
  (let ((current-stats (default-to {total-tickets-purchased: u0, total-amount-spent: u0, total-winnings: u0, rounds-participated: u0, rounds-won: u0} 
                                   (map-get? participant-history participant)))
        (current-round (var-get current-lottery-round))
        (round-stats (default-to {tickets-bought: u0, amount-spent: u0, winnings: u0}
                                 (map-get? participant-round-participation {participant: participant, round-number: current-round}))))
    (begin
      ;; Update overall participant history
      (map-set participant-history participant
        {total-tickets-purchased: (get total-tickets-purchased current-stats),
         total-amount-spent: (get total-amount-spent current-stats),
         total-winnings: (+ (get total-winnings current-stats) prize-amount),
         rounds-participated: (get rounds-participated current-stats),
         rounds-won: (+ (get rounds-won current-stats) u1)})
      
      ;; Update round-specific participation
      (map-set participant-round-participation {participant: participant, round-number: current-round}
        {tickets-bought: (get tickets-bought round-stats),
         amount-spent: (get amount-spent round-stats),
         winnings: (+ (get winnings round-stats) prize-amount)}))))

;; Lottery Initialization
(define-public (initialize-new-lottery (duration-blocks uint) (withdrawal-window-blocks uint) (price-per-ticket uint) (number-of-winners uint) (commission-percentage uint))
  (begin
    (asserts! (validate-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> price-per-ticket u0) ERR-INVALID-TICKET-PRICE)
    (asserts! (> number-of-winners u0) ERR-NO-WINNERS-AVAILABLE)
    (asserts! (<= commission-percentage maximum-organizer-fee-rate) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (var-get lottery-is-running)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> duration-blocks u0) ERR-INVALID-LOTTERY-DURATION)
    (asserts! (> withdrawal-window-blocks u0) ERR-INVALID-WITHDRAWAL-DURATION)
    
    ;; Increment round counter
    (var-set current-lottery-round (+ (var-get current-lottery-round) u1))
    
    (var-set lottery-is-running true)
    (var-set ticket-price-in-microstx price-per-ticket)
    (var-set total-prize-pool u0)
    (var-set tickets-sold-count u0)
    (var-set maximum-winner-count number-of-winners)
    (var-set lottery-closing-block (+ block-height duration-blocks))
    (var-set withdrawal-deadline-block (+ block-height withdrawal-window-blocks))
    (var-set organizer-fee-rate commission-percentage)
    (var-set winners-have-been-selected false)
    (var-set prizes-distributed false)
    (ok true)))

;; Ticket Purchase
(define-public (buy-lottery-ticket)
  (let ((current-ticket-cost (var-get ticket-price-in-microstx))
        (current-round (var-get current-lottery-round)))
    (begin
      (try! (ensure-lottery-is-active))
      (try! (verify-sufficient-balance current-ticket-cost))
      (try! (stx-transfer? current-ticket-cost tx-sender (as-contract tx-sender)))
      (var-set total-prize-pool (+ (var-get total-prize-pool) current-ticket-cost))
      (var-set tickets-sold-count (+ (var-get tickets-sold-count) u1))
      (map-set participant-ticket-registry {ticket-number: (var-get tickets-sold-count)} {participant-address: tx-sender})
      (map-set participant-ticket-balance tx-sender (+ (default-to u0 (map-get? participant-ticket-balance tx-sender)) u1))
      
      ;; Update participant history
      (update-participant-history-on-purchase tx-sender current-ticket-cost current-round)
      
      (ok (var-get tickets-sold-count)))))

;; Ticket Withdrawal
(define-public (refund-lottery-tickets (number-of-tickets uint))
  (let ((participant-total-tickets (default-to u0 (map-get? participant-ticket-balance tx-sender)))
        (refund-total-amount (* number-of-tickets (var-get ticket-price-in-microstx))))
    (begin
      (try! (ensure-lottery-is-active))
      (asserts! (<= block-height (var-get withdrawal-deadline-block)) ERR-WITHDRAWAL-DEADLINE-PASSED)
      (asserts! (>= participant-total-tickets number-of-tickets) ERR-NO-TICKETS-OWNED)
      (var-set total-prize-pool (- (var-get total-prize-pool) refund-total-amount))
      (var-set tickets-sold-count (- (var-get tickets-sold-count) number-of-tickets))
      (map-set participant-ticket-balance tx-sender (- participant-total-tickets number-of-tickets))
      (as-contract (stx-transfer? refund-total-amount tx-sender tx-sender)))))

;; Lottery Conclusion
(define-public (finalize-lottery-draw)
  (let ((complete-prize-pool (var-get total-prize-pool))
        (total-winner-count (var-get maximum-winner-count))
        (total-tickets-in-draw (var-get tickets-sold-count))
        (administrator-commission (compute-organizer-commission complete-prize-pool))
        (current-round (var-get current-lottery-round))
        (start-block (- (var-get lottery-closing-block) u144))) ;; Approximate start block
    (begin
      (asserts! (validate-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (>= block-height (var-get lottery-closing-block)) ERR-LOTTERY-STILL-RUNNING)
      (try! (ensure-lottery-is-active))
      (asserts! (> total-tickets-in-draw u0) ERR-NO-WINNERS-AVAILABLE)
      (var-set lottery-is-running false)
      (try! (as-contract (stx-transfer? administrator-commission tx-sender contract-administrator)))
      (let ((remaining-prize-pool (- complete-prize-pool administrator-commission)))
        (var-set individual-winner-prize (/ remaining-prize-pool total-winner-count)))
      
      ;; Record lottery history
      (map-set lottery-history-records 
        {round-number: current-round}
        {start-block: start-block,
         end-block: (var-get lottery-closing-block),
         ticket-price: (var-get ticket-price-in-microstx),
         total-tickets: total-tickets-in-draw,
         total-prize-pool: complete-prize-pool,
         winner-count: total-winner-count,
         prize-per-winner: (var-get individual-winner-prize),
         organizer-fee: administrator-commission,
         completion-timestamp: block-height})
      
      (var-set total-lotteries-completed (+ (var-get total-lotteries-completed) u1))
      (ok true))))

;; Winner Determination
(define-public (determine-lottery-winners (randomization-seed uint))
  (let ((total-winner-count (var-get maximum-winner-count))
        (total-available-tickets (var-get tickets-sold-count)))
    (begin
      (asserts! (validate-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (not (var-get lottery-is-running)) ERR-LOTTERY-NOT-ACTIVE)
      (asserts! (not (var-get winners-have-been-selected)) ERR-WINNERS-ALREADY-DETERMINED)
      (asserts! (> total-available-tickets u0) ERR-NO-WINNERS-AVAILABLE)
      (var-set winners-have-been-selected true)
      (let ((winner-selection-result (fold process-winner-selection
                                           (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
                                           {seed-value: randomization-seed, current-position: u0, remaining-selections: total-winner-count})))
        (ok (get current-position winner-selection-result))))))

;; Winner Selection Processing
(define-private (process-winner-selection (selection-index uint) (selection-context {seed-value: uint, current-position: uint, remaining-selections: uint}))
  (if (> (get remaining-selections selection-context) u0)
    (let ((selected-ticket-number (generate-winning-ticket-number (get seed-value selection-context) selection-index))
          (winning-participant-address (get participant-address (unwrap-panic (map-get? participant-ticket-registry {ticket-number: (+ selected-ticket-number u1)})))))
      (begin
        (map-set lottery-winner-registry {winner-position: (get current-position selection-context)} {winner-address: winning-participant-address, prize-claimed: false})
        
        ;; Record winner in history
        (map-set round-winner-history 
          {round-number: (var-get current-lottery-round), winner-position: (get current-position selection-context)}
          {winner-address: winning-participant-address, prize-amount: (var-get individual-winner-prize)})
        
        {seed-value: (+ (get seed-value selection-context) u1),
         current-position: (+ (get current-position selection-context) u1),
         remaining-selections: (- (get remaining-selections selection-context) u1)}))
    selection-context))

;; Automatic Prize Distribution
(define-public (distribute-all-prizes)
  (let ((total-winner-count (var-get maximum-winner-count))
        (prize-per-winner (var-get individual-winner-prize)))
    (begin
      (asserts! (validate-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (var-get winners-have-been-selected) ERR-WINNERS-NOT-DETERMINED)
      (asserts! (not (var-get prizes-distributed)) ERR-PRIZES-ALREADY-DISTRIBUTED)
      (asserts! (> prize-per-winner u0) ERR-NO-WINNERS-AVAILABLE)
      (let ((distribution-result (fold distribute-prize-to-winner
                                       (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
                                       {current-position: u0, total-winners: total-winner-count, prize-amount: prize-per-winner, success-count: u0})))
        (var-set prizes-distributed true)
        (ok (get success-count distribution-result))))))

;; Prize Distribution Helper Function
(define-private (distribute-prize-to-winner (index uint) (distribution-state {current-position: uint, total-winners: uint, prize-amount: uint, success-count: uint}))
  (if (< (get current-position distribution-state) (get total-winners distribution-state))
    (let ((winner-record-opt (map-get? lottery-winner-registry {winner-position: (get current-position distribution-state)})))
      (match winner-record-opt
        winner-record
        (let ((winner-address (get winner-address winner-record))
              (already-claimed (get prize-claimed winner-record)))
          (if (not already-claimed)
            (match (as-contract (stx-transfer? (get prize-amount distribution-state) tx-sender winner-address))
              success
              (begin
                (map-set lottery-winner-registry 
                  {winner-position: (get current-position distribution-state)} 
                  {winner-address: winner-address, prize-claimed: true})
                (update-participant-history-on-win winner-address (get prize-amount distribution-state))
                {current-position: (+ (get current-position distribution-state) u1),
                 total-winners: (get total-winners distribution-state),
                 prize-amount: (get prize-amount distribution-state),
                 success-count: (+ (get success-count distribution-state) u1)})
              error-response
              {current-position: (+ (get current-position distribution-state) u1),
               total-winners: (get total-winners distribution-state),
               prize-amount: (get prize-amount distribution-state),
               success-count: (get success-count distribution-state)})
            {current-position: (+ (get current-position distribution-state) u1),
             total-winners: (get total-winners distribution-state),
             prize-amount: (get prize-amount distribution-state),
             success-count: (get success-count distribution-state)}))
        {current-position: (+ (get current-position distribution-state) u1),
         total-winners: (get total-winners distribution-state),
         prize-amount: (get prize-amount distribution-state),
         success-count: (get success-count distribution-state)}))
    distribution-state))

;; Prize Claiming (Individual)
(define-public (claim-lottery-winnings (winner-position uint))
  (let ((winner-record (unwrap! (map-get? lottery-winner-registry {winner-position: winner-position}) ERR-WINNER-ID-NOT-FOUND))
        (registered-winner-address (get winner-address winner-record))
        (prize-already-claimed (get prize-claimed winner-record))
        (prize-amount (var-get individual-winner-prize)))
    (begin
      (asserts! (is-eq tx-sender registered-winner-address) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (not prize-already-claimed) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (not (var-get prizes-distributed)) ERR-PRIZES-ALREADY-DISTRIBUTED)
      (try! (transfer-winnings-to-recipient registered-winner-address prize-amount))
      (asserts! (< winner-position (var-get maximum-winner-count)) ERR-WINNER-ID-NOT-FOUND)
      (map-set lottery-winner-registry {winner-position: winner-position} {winner-address: registered-winner-address, prize-claimed: true})
      
      ;; Update participant history with winnings
      (update-participant-history-on-win registered-winner-address prize-amount)
      
      (ok true))))

;; Query Functions
(define-read-only (get-ticket-price)
  (ok (var-get ticket-price-in-microstx)))

(define-read-only (get-total-prize-pool)
  (ok (var-get total-prize-pool)))

(define-read-only (get-participant-ticket-count (participant-address principal))
  (ok (default-to u0 (map-get? participant-ticket-balance participant-address))))

(define-read-only (get-tickets-sold)
  (ok (var-get tickets-sold-count)))

(define-read-only (is-lottery-active)
  (ok (var-get lottery-is-running)))

(define-read-only (get-lottery-end-block)
  (ok (var-get lottery-closing-block)))

(define-read-only (get-withdrawal-deadline)
  (ok (var-get withdrawal-deadline-block)))

(define-read-only (get-commission-rate)
  (ok (var-get organizer-fee-rate)))

(define-read-only (get-winner-details (winner-position uint))
  (ok (map-get? lottery-winner-registry {winner-position: winner-position})))

(define-read-only (check-winners-selected)
  (ok (var-get winners-have-been-selected)))

(define-read-only (check-prizes-distributed)
  (ok (var-get prizes-distributed)))

;; History and Analytics Query Functions
(define-read-only (get-current-round)
  (ok (var-get current-lottery-round)))

(define-read-only (get-total-completed-lotteries)
  (ok (var-get total-lotteries-completed)))

(define-read-only (get-lottery-history (round-number uint))
  (ok (map-get? lottery-history-records {round-number: round-number})))

(define-read-only (get-round-winner (round-number uint) (winner-position uint))
  (ok (map-get? round-winner-history {round-number: round-number, winner-position: winner-position})))

(define-read-only (get-participant-overall-stats (participant principal))
  (ok (map-get? participant-history participant)))

(define-read-only (get-participant-round-stats (participant principal) (round-number uint))
  (ok (map-get? participant-round-participation {participant: participant, round-number: round-number})))

(define-read-only (calculate-participant-roi (participant principal))
  (let ((stats (map-get? participant-history participant)))
    (match stats
      participant-data
      (let ((total-spent (get total-amount-spent participant-data))
            (total-won (get total-winnings participant-data)))
        (if (> total-spent u0)
          (ok (some (/ (* total-won u100) total-spent)))
          (ok none)))
      (ok none))))