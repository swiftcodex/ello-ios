//
//  ElloLabel.swift
//  Ello
//
//  Created by Sean on 3/18/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation


public class ElloLabel: UILabel {
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if let text = self.text {
            self.setLabelText(text, color: textColor)
        }
    }

    public init() {
        super.init(frame: CGRectZero)
    }
}

// MARK: UIView Overrides
extension ElloLabel {
    public override func sizeThatFits(size: CGSize) -> CGSize {
        var size = super.sizeThatFits(size)
        size.height = heightForWidth(size.width) + 10
        return size
    }
}

public extension ElloLabel {
    func setLabelText(title: String, color: UIColor = UIColor.whiteColor(), alignment: NSTextAlignment = .Left) {
        var attributedString = NSMutableAttributedString(string: title)
        var range = NSRange(location: 0, length: count(title))
        attributedString.addAttributes(attributes(title, color: color, alignment: alignment), range: range)
        self.attributedText = attributedString
    }

    func height() -> CGFloat {
        return heightForWidth(self.frame.size.width)
    }

    func heightForWidth(width: CGFloat) -> CGFloat {
        return (attributedText?.boundingRectWithSize(CGSize(width: width, height: CGFloat.max),
            options: .UsesLineFragmentOrigin | .UsesFontLeading,
            context: nil).size.height).map(ceil) ?? 0
    }
}

private extension ElloLabel {
    func attributes(title: String, color: UIColor, alignment: NSTextAlignment) -> [NSObject : AnyObject] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10
        paragraphStyle.alignment = alignment

        var attributedString = NSMutableAttributedString(string: title)
        var range = NSRange(location: 0, length: count(title))
        return [
            NSFontAttributeName : UIFont.typewriterFont(12.0),
            NSForegroundColorAttributeName : color,
            NSParagraphStyleAttributeName : paragraphStyle
        ]
    }
}

public class ElloToggleLabel: ElloLabel {
    public override func setLabelText(title: String, color: UIColor = UIColor.greyA(), alignment: NSTextAlignment = .Left) {
        super.setLabelText(title, color: color, alignment: alignment)
    }
}

public class ElloErrorLabel: ElloLabel {
    public override func setLabelText(title: String, color: UIColor = UIColor.redColor(), alignment: NSTextAlignment = .Left) {
        super.setLabelText(title, color: color, alignment: alignment)
    }
}
