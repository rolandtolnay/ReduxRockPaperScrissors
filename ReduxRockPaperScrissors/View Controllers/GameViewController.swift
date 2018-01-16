//
//  ViewController.swift
//  ReduxRockPaperScrissors
//
//  Created by Roland Tolnay on 10/12/2017.
//  Copyright © 2017 Roland Tolnay. All rights reserved.
//

import UIKit
import ReSwift

class GameViewController: UIViewController, StoreSubscriber {

  // MARK: - IBOutlets

  @IBOutlet weak var otherPlayerNameLabel: UILabel!
  @IBOutlet weak var localPlayerNameLabel: UILabel!

  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var playerLabel: UILabel!
  @IBOutlet weak var pendingStartLabel: UILabel!

  @IBOutlet weak var localPlayerWeapon: UIImageView!
  @IBOutlet weak var otherPlayerWeapon: UIImageView!

  @IBOutlet weak var localPlayerScoreLabel: UILabel!
  @IBOutlet weak var otherPlayerScoreLabel: UILabel!

  @IBOutlet weak var rockImageView: UIImageView!
  @IBOutlet weak var paperImageView: UIImageView!
  @IBOutlet weak var scrissorsImageView: UIImageView!

  @IBOutlet weak var startGameButton: UIButton!
  @IBOutlet weak var leaveButton: UIButton!
  @IBOutlet weak var lowerBackgroundView: UIView!
  @IBOutlet weak var upperBackgroundView: UIView!

  var isCountdownRunning = false
  var countdownTimer = Timer()

  // MARK: -
  // MARK: Lifecycle
  // --------------------

  override func viewDidLoad() {
    super.viewDidLoad()

    lowerBackgroundView.backgroundColor = UIColor(displayP3Red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
    upperBackgroundView.backgroundColor = UIColor(displayP3Red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    mainStore.subscribe(self)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.sendSubview(toBack: lowerBackgroundView)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    mainStore.unsubscribe(self)
  }

  // MARK: -
  // MARK: Tap handlers
  // --------------------

  @IBAction func onRockTap(_ sender: UITapGestureRecognizer) {
    mainStore.dispatch(
      ChooseWeaponAction(player: .local, weapon: .rock)
    )
  }
  @IBAction func onPaperTap(_ sender: UITapGestureRecognizer) {
    mainStore.dispatch(
      ChooseWeaponAction(player: .local, weapon: .paper)
    )
  }
  @IBAction func onScrissorsTap(_ sender: Any) {
    mainStore.dispatch(
      ChooseWeaponAction(player: .local, weapon: .scrissors)
    )
  }

  @IBAction func onStartGameTapped(_ sender: UIButton) {
    mainStore.dispatch(
      RequestStartGameAction()
    )
  }

  @IBAction func onLeaveTapped(_ sender: UIButton) {
    self.dismiss(animated: true)
    mainStore.dispatch(
      StopBrowsingPeers()
    )
  }
  // MARK: -
  // MARK: Render state
  // --------------------

  func newState(state: AppState) {
    guard state.multipeerState.session != nil else {
      self.dismiss(animated: true) {
        self.showOpponentLeftAlert()
      }
      return
    }
    let gameState = state.gameState

    playerLabel.text = gameState.playerMessage
    if let countdown = gameState.currentCountdown, statusLabel.text != String(countdown) {
      statusLabel.text = String(countdown)
      statusLabel.transform = CGAffineTransform(scaleX: 1, y: 1)
      UIView.animate(withDuration: 1, animations: {
        self.statusLabel.transform = CGAffineTransform(scaleX: 2, y: 2)
      })
    }
    if gameState.gameStatus != .countdown {
      statusLabel.transform = CGAffineTransform(scaleX: 1, y: 1)
      statusLabel.text = gameState.statusMessage
    }

    renderPlayerNames(from: state.multipeerState)
    updateScore(from: state)

    toggleWeaponInteraction(enabled: gameState.result == nil)
    toggleWeaponVisibility(isHidden: gameState.gameStatus != .countdown)

    if gameState.result != nil {
      otherPlayerWeapon.image = imageFrom(weapon: gameState.otherPlay.weapon!, player: .other)
      localPlayerWeapon.image = imageFrom(weapon: gameState.localPlay.weapon!, player: .local)
    } else {
      otherPlayerWeapon.image = imageFrom(weapon: nil, player: .other)
      localPlayerWeapon.image = imageFrom(weapon: gameState.localPlay.weapon, player: .local)
    }

    renderGameStatus(gameState.gameStatus, for: gameState.result)
  }

  // MARK: -
  // MARK: Utility
  // --------------------

  private func renderPlayerNames(from multipeerState: MultipeerState) {
    localPlayerNameLabel.text = UIDevice.current.name
    otherPlayerNameLabel.text = multipeerState.connectedPlayer
  }

  private func renderGameStatus(_ gameStatus: GameStatus, for result: Result? = nil) {
    if gameStatus != .countdown && isCountdownRunning {
      toggleTimer(enabled: false)
    }

    switch gameStatus {
      case .pendingStartReceived:
        showRequestGameStartAlert { didAccept in
          mainStore.dispatch(
            RespondStartGameAction(canStart: didAccept, gameStatus: gameStatus)
          )
        }
      case .pendingStartSent:
        startGameButton.isHidden = true
        leaveButton.isHidden = true
        pendingStartLabel.isHidden = false
      case .finished:
        startGameButton.isHidden = false
        leaveButton.isHidden = false
        pendingStartLabel.isHidden = true
        if let result = result {
          grayscaleImagesForResult(result, playerOne: &localPlayerWeapon.image!, playerTwo: &otherPlayerWeapon.image!)
        }
      case .countdown:
        toggleTimer(enabled: true)
        startGameButton.isHidden = true
        leaveButton.isHidden = true
        pendingStartLabel.isHidden = true
    }
  }

  typealias AlertResult = (_ didAccept: Bool) -> Void

  private func showRequestGameStartAlert(completion: @escaping AlertResult) {
    let opponent = mainStore.state.multipeerState.connectedPlayer!
    let alert = UIAlertController(title: "Start game",
                                  message: "\(opponent) would like to start the game. Are you ready?",
                                  preferredStyle: .alert)
    let acceptAction = UIAlertAction(title: "Accept", style: .cancel) { _ in
      completion(true)
    }
    let declineAction = UIAlertAction(title: "Decline", style: .default) { _ in
      completion(false)
    }

    alert.addAction(acceptAction)
    alert.addAction(declineAction)

    present(alert, animated: true, completion: nil)
  }

  private func showOpponentLeftAlert() {
    let alert = UIAlertController(title: nil,
                                  message: "Your opponent has left the game.",
                                  preferredStyle: .alert)
    let okAction = UIAlertAction(title: "Done", style: .default)
    alert.addAction(okAction)

    let appDelegate = UIApplication.shared.delegate as! AppDelegate // swiftlint:disable:this force_cast
    let rootVC = appDelegate.window!.rootViewController!
    rootVC.present(alert, animated: true, completion: nil)
  }

  private func toggleWeaponInteraction(enabled: Bool) {
    rockImageView.isUserInteractionEnabled = enabled
    paperImageView.isUserInteractionEnabled = enabled
    scrissorsImageView.isUserInteractionEnabled = enabled
  }

  private func toggleWeaponVisibility(isHidden: Bool) {
    rockImageView.isHidden = isHidden
    paperImageView.isHidden = isHidden
    scrissorsImageView.isHidden = isHidden
    playerLabel.isHidden = isHidden
  }

  private func toggleTimer(enabled: Bool) {
    guard enabled else {
      countdownTimer.invalidate()
      isCountdownRunning = false
      // TODO: Refactor score handling
      mainStore.dispatch(
        UpdateScoreAction()
      )
      vibratePhone()
      return
    }

    if !isCountdownRunning {
      countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        mainStore.dispatch(
          CountdownTickAction()
        )
      }
      isCountdownRunning = true
      vibratePhone()
    }
  }

  private func imageFrom(weapon: Weapon?, player: Player) -> UIImage? {
    guard let weapon = weapon else {
      return UIImage(named: "none")
    }

    let playerPrefix = player == .local ? "p1-" : "p2-"
    switch weapon {
      case .rock:
        return UIImage(named: playerPrefix+"rock")
      case .paper:
        return UIImage(named: playerPrefix+"paper")
      case .scrissors:
        return UIImage(named: playerPrefix+"scrissors")
    }
  }

  private func grayscaleImagesForResult(_ result: Result?, playerOne: inout UIImage, playerTwo: inout UIImage) {
    guard let result = result else { return }

    switch result {
      case .localWin:
        playerTwo = convertToGrayScale(image: playerTwo)
      case .otherWin:
        playerOne = convertToGrayScale(image: playerOne)
      default: // draw
        break
    }
  }

  private func updateScore(from state: AppState) {
    guard let p1Score = state.score[Player.local],
      let p2Score = state.score[Player.other] else { return }

    localPlayerScoreLabel.text = String(p1Score)
    otherPlayerScoreLabel.text = String(p2Score)
  }
}
