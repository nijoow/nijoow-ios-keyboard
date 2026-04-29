import UIKit

extension KeyboardViewController {
  
  // MARK: - 팝업 및 변체 입력 (Long Press)


  @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard let btn = gesture.view as? KeyButton, let firstChar = btn.keyValue.first else { return }
    let char = letterLabel(for: firstChar)
    
    switch gesture.state {
    case .began:
        let variants = getVariants(for: char)
      if variants.count <= 1 {
        gesture.state = .failed
        return
      }
      showPopup(for: btn, variants: variants)
      updatePopupSelection(touchLocationInView: gesture.location(in: self.view))
    case .changed:
      updatePopupSelection(touchLocationInView: gesture.location(in: self.view))
    case .ended:
      if popupSelectedIndex >= 0 && popupSelectedIndex < popupItems.count {
        insertVariant(popupItems[popupSelectedIndex])
      }
      hidePopup()
    case .cancelled, .failed:
      hidePopup()
    default:
      break
    }
  }

  func getVariants(for char: String) -> [String] {
    if isHangul {
      switch char {
      case "ㅂ": return ["ㅂ", "ㅃ"]; case "ㅈ": return ["ㅈ", "ㅉ"]
      case "ㄷ": return ["ㄷ", "ㄸ"]; case "ㄱ": return ["ㄱ", "ㄲ"]
      case "ㅅ": return ["ㅅ", "ㅆ"]; case "ㅐ": return ["ㅐ", "ㅒ"]
      case "ㅔ": return ["ㅔ", "ㅖ"]; case "ㅃ": return ["ㅃ", "ㅂ"]
      case "ㅉ": return ["ㅉ", "ㅈ"]; case "ㄸ": return ["ㄸ", "ㄷ"]
      case "ㄲ": return ["ㄲ", "ㄱ"]; case "ㅆ": return ["ㅆ", "ㅅ"]
      case "ㅒ": return ["ㅒ", "ㅐ"]; case "ㅖ": return ["ㅖ", "ㅔ"]
      default: return [char]
      }
    } else if !isSymbol && !isCustom {
      let lower = char.lowercased()
      let upper = char.uppercased()
      return lower != upper ? [lower, upper] : [char]
    }
    return [char]
  }

  func showPopup(for btn: KeyButton, variants: [String]) {
    hidePopup()
    popupItems = variants
    popupSelectedIndex = -1
    
    let popup = UIView()
    popup.layer.cornerRadius = 10
    popup.layer.shadowColor = UIColor.black.cgColor
    popup.layer.shadowOpacity = isDarkMode ? 0.5 : 0.2
    popup.layer.shadowRadius = 4
    popup.layer.shadowOffset = CGSize(width: 0, height: 2)

    let blurStyle: UIBlurEffect.Style = isDarkMode ? .systemMaterialDark : .systemMaterialLight
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    blur.layer.cornerRadius = 10
    blur.layer.masksToBounds = true
    popup.addSubview(blur)
    
    let btnFrame = btn.convert(btn.bounds, to: self.view)
    let itemWidth: CGFloat = max(btnFrame.width * 1.2, 40)
    let itemHeight: CGFloat = btnFrame.height * 1.2
    
    popup.frame = CGRect(
        x: btnFrame.midX - (CGFloat(variants.count) * itemWidth) / 2,
        y: btnFrame.minY - itemHeight - 8,
        width: CGFloat(variants.count) * itemWidth,
        height: itemHeight
    )
    
    if popup.frame.minX < 5 { popup.frame.origin.x = 5 }
    else if popup.frame.maxX > self.view.bounds.width - 5 {
      popup.frame.origin.x = self.view.bounds.width - 5 - popup.frame.width
    }
    blur.frame = popup.bounds
    
    for (i, v) in variants.enumerated() {
        let lbl = UILabel(frame: CGRect(x: CGFloat(i) * itemWidth, y: 0, width: itemWidth, height: itemHeight))
        lbl.text = v
        lbl.font = UIFont.systemFont(ofSize: KeyboardConstants.KEY_FONT_SIZE + 4, weight: .medium)
        lbl.textAlignment = .center
        lbl.textColor = keyTextColor
        lbl.layer.cornerRadius = 6
        lbl.layer.masksToBounds = true
        popup.addSubview(lbl)
        popupLabels.append(lbl)
    }
    self.view.addSubview(popup)
    self.popupView = popup
  }

  func updatePopupSelection(touchLocationInView: CGPoint) {
    guard let popup = popupView, !popupItems.isEmpty else { return }
    let localX = touchLocationInView.x - popup.frame.minX
    let itemWidth = popup.bounds.width / CGFloat(popupItems.count)
    var newIdx = Int(localX / itemWidth)
    if newIdx < 0 { newIdx = 0 }
    if newIdx >= popupItems.count { newIdx = popupItems.count - 1 }
    
    if popupSelectedIndex != newIdx {
            popupSelectedIndex = newIdx
    }
    
    for (i, lbl) in popupLabels.enumerated() {
        lbl.backgroundColor = (i == popupSelectedIndex) ? activeGlassColor : .clear
        lbl.textColor = (i == popupSelectedIndex && isDarkMode) ? .white : ((i == popupSelectedIndex) ? .black : keyTextColor)
    }
  }

  func hidePopup() {
    popupView?.removeFromSuperview()
    popupView = nil
    popupLabels.removeAll()
    popupItems.removeAll()
    popupSelectedIndex = -1
  }

  func insertVariant(_ selected: String) {
    if isHangul {
      // 기존 조합 중인 글자 삭제 (밑줄 없는 효과를 위해)
      for _ in 0..<activeLength {
        textDocumentProxy.deleteBackward();
      }
      
      automata.backspace();
      automata.input(Character(selected));
      let combined = automata.compose();
      
      if !combined.isEmpty {
        textDocumentProxy.insertText(combined);
        activeLength = combined.count;
        composingChar = combined.last;
      } else {
        activeLength = 0;
        composingChar = nil;
      }
    } else {
      textDocumentProxy.insertText(selected)
    }
    if isShifted {
        isShifted = false
        rebuildKeyboard()
    }
  }

  // MARK: - 문자 레이블 및 아이콘 드로잉
  
  func letterLabel(for char: Character) -> String {
    if isHangul {
      if isShifted, let s = KeyboardConstants.HANGUL_SHIFT_MAP[char] { return String(s) }
      return String(KeyboardConstants.HANGUL_MAP[char] ?? char)
    } else {
      return isShifted ? String(char).uppercased() : String(char)
    }
  }

  enum CursorIconType { case lineStart, left, right, lineEnd }

  func drawCursorImage(type: CursorIconType, size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let ctx = context.cgContext
      ctx.setShouldAntialias(true)
      UIColor.white.setFill(); UIColor.white.setStroke()
      
      let w = size.width; let h = size.height
      let midX = w / 2; let midY = h / 2
      let barW: CGFloat = 2.0; let triW: CGFloat = 8.5; let triH: CGFloat = 9.0; let gap: CGFloat = 2.0
      let rounding: CGFloat = 1.5
      
      switch type {
      case .lineStart:
        let barRect = CGRect(x: midX - (triW + gap + barW)/2, y: midY - triH/2, width: barW, height: triH)
        UIBezierPath(roundedRect: barRect, cornerRadius: barW/2).fill()
        let path = UIBezierPath()
        let apexX = barRect.maxX + gap
        path.move(to: CGPoint(x: apexX, y: midY))
        path.addLine(to: CGPoint(x: apexX + triW, y: midY - triH/2)); path.addLine(to: CGPoint(x: apexX + triW, y: midY + triH/2)); path.close()
        path.lineJoinStyle = .round; path.lineWidth = rounding; path.fill(); path.stroke()
      case .left:
        let path = UIBezierPath(); path.move(to: CGPoint(x: midX - triW/2, y: midY))
        path.addLine(to: CGPoint(x: midX + triW/2, y: midY - triH/2)); path.addLine(to: CGPoint(x: midX + triW/2, y: midY + triH/2)); path.close()
        path.lineJoinStyle = .round; path.lineWidth = rounding; path.fill(); path.stroke()
      case .right:
        let path = UIBezierPath(); path.move(to: CGPoint(x: midX + triW/2, y: midY))
        path.addLine(to: CGPoint(x: midX - triW/2, y: midY - triH/2)); path.addLine(to: CGPoint(x: midX - triW/2, y: midY + triH/2)); path.close()
        path.lineJoinStyle = .round; path.lineWidth = rounding; path.fill(); path.stroke()
      case .lineEnd:
        let barX = midX + (triW + gap + barW)/2 - barW; let apexX = barX - gap
        let path = UIBezierPath(); path.move(to: CGPoint(x: apexX, y: midY))
        path.addLine(to: CGPoint(x: apexX - triW, y: midY - triH/2)); path.addLine(to: CGPoint(x: apexX - triW, y: midY + triH/2)); path.close()
        path.lineJoinStyle = .round; path.lineWidth = rounding; path.fill(); path.stroke()
        let barRect = CGRect(x: barX, y: midY - triH/2, width: barW, height: triH)
        UIBezierPath(roundedRect: barRect, cornerRadius: barW/2).fill()
      }
    }
  }
}
