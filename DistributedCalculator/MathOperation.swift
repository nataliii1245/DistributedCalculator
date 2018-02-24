//
//  MathOperation.swift
//  DistributedCalculator
//
//  Created by Наталия Волкова on 23.02.2018.
//  Copyright © 2018 natalii. All rights reserved.
//

import Foundation

final class MathOperation: Decodable {
    
    // MARK: - Публичные свойства
    
    // Математический оператор
    let action: String
    // Операнд
    let operand: Double
    
    // MARK: - Инициализация
    
    init(action: String, operand: Double) {
        self.action = action
        self.operand = operand
    }
    
}
