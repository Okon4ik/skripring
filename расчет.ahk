#Persistent                      ; Скрипт будет работать постоянно, пока явно не будет остановлен
#NoEnv                          ; Отключает использование переменных окружения (устаревшее поведение)
SendMode Input                  ; Устанавливает быстрый и надёжный метод ввода
SetTitleMatchMode, 2           ; Позволяет искать окна по части заголовка
SetWorkingDir %A_ScriptDir%    ; Устанавливает рабочую директорию как директорию скрипта
SetBatchLines, -1              ; Максимальная производительность скрипта

clipboard := ""                ; Очищаем буфер обмена в начале

; --- Глобальные переменные ---
global vars := []              ; Массив переменных, например: var1..var12
global recording := false      ; Флаг обычного режима записи
global isCollecting := false   ; Флаг режима сбора значений
global sumMode := false        ; Флаг режима накопления суммы
global copiedCount := 0        ; Сколько значений скопировано
global sumList := []           ; Массив накопленных чисел
global sumStep := 1            ; Текущий шаг режима накопления
global allowExtended := true   ; Разрешён ли расширенный сбор данных

; --- Функции ---

; Очищает все переменные
ClearVars() {
    global vars
    vars := []  ; Сбрасываем массив
}

; Обработка обычного режима записи: записывает значения в vars[1]..vars[12]
HandleRecording(value) {
    global vars
    Loop, 12 {
        if (!vars[A_Index]) {
            vars[A_Index] := value
            ToolTip, Скопировано значение %A_Index% / 12
            SetTimer, RemoveToolTip, -500
            break
        }
    }
}

; Обработка альтернативного (ограниченного) режима записи: первые 4 значения
HandleRecordingAlt(value) {
    global vars, copiedCount
    copiedCount++
    if (copiedCount <= 4) {
        vars[copiedCount] := value
        ToolTip, Скопировано значение %copiedCount% / 4
        SetTimer, RemoveToolTip, -500
    }
    if (copiedCount = 4) {
        MsgBox, Активируйте Ctrl + Numpad1 для перехода в режим накопления.
    }
}

; Обработка значений в режиме суммирования (накопление чисел)
HandleSumMode(value) {
    global sumList
    ; Удаление лишних символов, замена запятой на точку
    value := RegExReplace(value, "[^\d\.\,]", "")
    value := StrReplace(value, ",", ".")
    
    ; Если это число — добавляем в список и выводим сумму
    if (value is number) {
        sumList.Push(value + 0) ; Преобразование в число
        sumTotal := 0
        for _, val in sumList
            sumTotal += val
        ToolTip, % "Сумма: " . sumTotal . " ₽`nВсего значений: " . sumList.Length()
        SetTimer, RemoveToolTip, -2000
    } else {
        MsgBox, Значение "%value%" не является числом.
    }
}

; Скрытие всплывающей подсказки
RemoveToolTip:
ToolTip
return

; Применение шаблона с подстановкой значений из vars
ApplyTemplate(template) {
    global vars
    Loop, 12 {
        val := vars[A_Index]
        if (!val)
            val := ""

        ; Форматирование чисел
        clean := RegExReplace(val, "[^\d\.,]", "")
        clean := StrReplace(clean, ",", ".")
        dotPos := InStr(clean, ".")
        if (dotPos) {
            intPart := SubStr(clean, 1, dotPos - 1)
            decPart := SubStr(clean, dotPos + 1)
            if (StrLen(decPart) > 2)
                decPart := SubStr(decPart, 1, 2)
            val := intPart . "." . decPart
        } else if (clean != "") {
            val := clean
        }

        ; Замена {var1}, {var2}, ... в шаблоне
        template := StrReplace(template, "{var" . A_Index . "}", val)
    }
    return template
}

; Переключает режим накопления (включает/выключает)
ToggleSumMode(step) {
    global sumMode, sumStep
    if (!sumMode) {
        StartSumMode(step)
    } else if (sumStep = step) {
        CompleteSumMode()
    } else {
        MsgBox, Уже активен другой режим накопления (шаг %sumStep%). Завершите его сначала.
    }
}

; Старт накопления чисел (активация режима)
StartSumMode(step) {
    global sumMode, isCollecting, sumList, copiedCount, sumStep
    sumList := []
    sumMode := true
    isCollecting := true
    copiedCount := 0
    sumStep := step
    MsgBox, Режим накопления #%step% активирован. Копируйте числа, затем снова нажмите Ctrl + Numpad%step%.
}

; Завершение накопления: суммирует и сохраняет результат
CompleteSumMode() {
    global sumList, sumStep, sumMode, isCollecting, allowExtended, vars
    sumTotal := 0
    for _, val in sumList
        sumTotal += val

    varNum := 4 + sumStep ; Пример: шаг 1 -> var5
    vars[varNum] := sumTotal
    MsgBox, Итоговая сумма %sumTotal% ₽ добавлена в var%varNum%.

    ; Выход из режимов
    sumMode := false
    isCollecting := false

    ; Подсказки по дальнейшим шагам
    if (sumStep = 1)
        MsgBox, Для второго значения нажми Ctrl + Numpad2
    else if (sumStep = 4) {
        ; Здесь вызывается обычный MsgBox с выбором "Да/Нет"
        result := MsgBox("Нужно копировать значения поездки за городом?", 4)
        if (result = "No")
            allowExtended := false
    }
}

; Обёртка над вызовом MessageBox API
MsgBox(message, type := 0) {
    If (type = 0)
        return DllCall("MessageBox", "ptr", 0, "str", message, "str", "AHK", "uint", 0)
    else
        return DllCall("MessageBox", "ptr", 0, "str", message, "str", "AHK", "uint", 0x00000004) = 6 ? "Yes" : "No"
}

; --- Горячие клавиши ---

; Режим 1: обычная запись (Alt + Num1)
!Numpad1::
    ClearVars()
    recording := true
    isCollecting := false
    sumMode := false
    MsgBox, Режим записи 1 активирован. Переменные очищены.
return

; Режим 2: запись с накоплением (Alt + Num2)
!Numpad2::
    ClearVars()
    isCollecting := true
    recording := false
    sumMode := false
    copiedCount := 0
    sumList := []
    sumStep := 1
    allowExtended := true
    MsgBox, Режим записи 2 активирован. Используй Ctrl+C для сбора данных.
return

; Ctrl+C — перехватывает буфер обмена и вызывает соответствующую обработку
~^c::
    if !(recording || isCollecting || sumMode)
        return

    ClipSaved := ClipboardAll
    Clipboard := ""
    Send ^c
    ClipWait, 1
    if (Clipboard != "") {
        value := Clipboard
        if (recording)
            HandleRecording(value)
        else if (isCollecting && !sumMode)
            HandleRecordingAlt(value)
        else if (sumMode)
            HandleSumMode(value)
    }
    Clipboard := ClipSaved
return

; Ctrl + Num1..Num8 — переключают шаги режима накопления (если разрешено)
^Numpad1::ToggleSumMode(1)
return

^Numpad2::
    if (allowExtended)
        ToggleSumMode(2)
return

^Numpad3::
    if (allowExtended)
        ToggleSumMode(3)
return

^Numpad4::
    if (allowExtended)
        ToggleSumMode(4)
return

^Numpad5::
    if (allowExtended)
        ToggleSumMode(5)
return

^Numpad6::
    if (allowExtended)
        ToggleSumMode(6)
return

^Numpad7::
    if (allowExtended)
        ToggleSumMode(7)
return

^Numpad8::
    if (allowExtended)
        ToggleSumMode(8)
return

; Вставка текста по шаблону (Alt + 1)
!s::
template := "
(
В цену этого заказа вошли:

— {var4} ₽ — это минимальная стоимость заказа по тарифу {{НАПИШИ_КАКОЙ}}. В эту сумму включены первые {var1} мин поездки, {var2} км и {var3} мин бесплатного ожидания

— ХХ ₽ за ХХ мин ожидания на месте и ХХ ₽ за XX мин ожидания в пути

— {var6} ₽ за {var5} км в пути

— {var8} ₽ за {var7} мин в пути

— Часть пути вы проехали за городом — это {var10} ₽ за {var9} км и {var12} ₽ за {var11} мин

— Ещё XXX ₽ — за платную подачу

— За дополнительные услуги: Детское_кресло, Перевозка_животных, скидка «Яндекс Плюса, НАПИШИ_КАКАЯ_УСЛУГА — XXX ₽

{{ЕСЛИ_БЫЛ_СУРЖ}}
Ещё на цену заказа повлиял высокий спрос. Всё вместе — {{XXX}} ₽ за заказ

{{ЕСЛИ_НЕ_БЫЛО_СУРЖА}}
Всё вместе — {{XXX}} ₽ за заказ
)"
    finalText := ApplyTemplate(template)
    Clipboard := finalText
    ClipWait, 1
    Send ^v

    ; Выход из всех режимов
    recording := false
    isCollecting := false
    sumMode := false
return

; Ctrl+Shift+X — сброс переменных вручную
^+x::
    ClearVars()
    MsgBox, Переменные очищены.
return
