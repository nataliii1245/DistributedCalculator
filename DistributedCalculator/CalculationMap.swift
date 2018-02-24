//
//  CalculationMap.swift
//  DistributedCalculator
//
//  Created by Наталия Волкова on 23.02.2018.
//  Copyright © 2018 natalii. All rights reserved.
//

import Foundation

final class CalculationMap: Decodable {
    
    // MARK: - Публичные свойства
    
    // Начальное значение
    var currentNumber: Double
    // Математическая операция
    var mathOperations: [MathOperation]
    
    
    // MARK: - Инициализация
    
    init?(data: Data) {
        guard let string = String(data: data, encoding: .ascii) else { return nil }
        
        // Сочетание, обозначающее конец строки
        let endLine = "\r\n"
        // Разделить строку на массив строк по сочетанию конца строки
        var items = string.components(separatedBy: endLine).filter { !$0.isEmpty }
        
        guard !items.isEmpty else { return nil }
        
        // Получить начальный символ
        guard let currentNumber = Double(items.removeFirst()) else { return nil }
        self.currentNumber = currentNumber
        
        // Получить массив операций
        let mathOperations: [MathOperation] = items.flatMap { item in
            let components = item.components(separatedBy: " ").filter { !$0.isEmpty }
            guard components.count == 2, let operand = Double(components[1]) else { return nil }
            
            let mathOperation = MathOperation(action: components[0], operand: operand)
            return mathOperation
        }
        guard !mathOperations.isEmpty else { return nil }
        
        self.mathOperations = mathOperations
    }
    
}


// MARK: - Публичные свойства

extension CalculationMap {
    
    // Сформировать строку для отправки
    var data: Data? {
        // Объединить операции в массив строк
        var items = self.mathOperations.map { "\($0.action) \($0.operand)" }
        // Вставить на нулевую позицию текущий результат
        items.insert("\(self.currentNumber)", at: 0)
        
        // Сочетание, обозначающее конец строки
        let endLine = "\r\n"
        // Получить строку из массива
        let string = items.map { $0 + endLine }.reduce("") { $0 + $1 }
        
        // Получить бинарные данные в формате ASCII
        let data = string.data(using: .ascii)
        return data
    }
    
}
