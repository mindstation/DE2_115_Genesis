# [SEGA Megadrive/Genesis](https://en.wikipedia.org/wiki/Sega_Genesis) для платы Terasic DE2-115.

Это порт ядра [Genesis_MiSTer](https://github.com/MiSTer-devel/Genesis_MiSTer).

Genesis_MiSTer, в свою очередь, основан на проекте [fpgagen](https://github.com/Torlus/fpgagen).

fpgagen - это клон SEGA Megadrive/Genesis для платы Terasic DE2, MiST и Turbo Chameleon 64. Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com)
All rights reserved

Проект DE2_115_Genesis был создан с использованием Quartus Prime 17.0.2 Lite Edition.


## Установка

Запишите желаемый ROM во FLASH микросхему платы DE2-115 при помощи "Terasic-DE2-115 Control Panel":

1. выберите FLASH память из списка доступных на плате
2. выполните полное стирание FLASH чипа (необходимо выполнять перед каждой записью)
3. в блоке "Sequential Write block" поставьте галочку "File Length"
4. в блоке "Sequential Write block нажмите кнопку "Write a File to Memory" и в появившемся окне выберите ROM файл

Загрузите "output_files/DE2_115_Genesis.sof" в ПЛИС. Копирование ROM из FLASH в SDRAM память запустится автоматически, при этом загорится LEDR0.
Когда копирование будет завершено LEDR0 погаснет и ROM запустится.

Размер ROM определяется проектом автоматически, при копировании в SDRAM, по максимальному адресу указанному в заголовке ROM. Исключение Super Street Fighter 2 New Challengers.
Размер SSF2 NC равный 5 МБ указан в проекте явно, так как он не совпадает с размером в заголовке ROM.


## Кнопки и переключатели на плате

Используются следующие кнопки и переключатели:

* SW[16] - сброс Mega Drive/Genesis
* SW[5]  - joystick_0_B, SW[4] - joystick_0_C, SW[3] - joystick_0_Left, SW[2] - joystick_0_Up, SW[1] - joystick_0_Down, SW[0] - joystick_0_Right
* KEY[3] - joystick_0_START, KEY[2] - joystick_0_A
* SW[12] - joystick_1_B, SW[11] - joystick_1_C, SW[10] - joystick_1_Left, SW[9] - joystick_1_Up, SW[8] - joystick_1_Down, SW[7] - joystick_1_Right
* KEY[1] - joystick_1_START, KEY[0] - joystick_1_A


## Геймпады

### Геймпады Mega Drive и Genesis

К контактам GPIO на DE2-115 можно подключать геймпады Mega Drive и Genesis в режиме совместимости с Master System.
В этом режиме работают только кнопки B, C и крестовина.

Схему подключения смотрите в файле "schematics/DE2-115 Genesis and Mega Drive gamepads 3V3 adapter.pdf", для варианта с питанием 3,3В.
Для варианта с питанием 5В смотрите схему с преобразователем логических уровней - "schematics/DE2-115 Genesis and Mega Drive gamepads 5V adapter.pdf".

Назначение контактов GPIO для геймпадов первого и второго игрока:

* JP5 pin 15, JP5 pin 19, JP5 pin 23, JP5 pin 27, JP5 pin 33, JP5 pin 37 - gamepad 1 (CBUDLR, инвертированная логика)
* JP5 pin  2, JP5 pin  4, JP5 pin  6, JP5 pin  8, JP5 pin 10, JP5 pin 14 - gamepad 2 (CBUDLR, инвертированная логика)

Назначение контактов на разъеме геймпада Mega Drive/Genesis в режиме совместимости с Master System (питание 3,3В):

pin 9 - кнопка C, pin 6 - кнопка B, pin 1 - вверх (Up), pin 2 - вниз (Down), pin 3 - влево (Left), pin 4 - вправо (Right), pin 5 - питание 3,3В,
pin 7 - сигнал выбора набора кнопок геймпада (3,3В), pin 8 - земля

Большинство геймпадов Mega Drive и Genesis прекрасно работают с трехвольтовым питанием. Если ваш геймпад не работает от 3,3В,
попробуйте пятивольтовую схему подключения.

### Геймпады Master System

К GPIO на DE2-115 также можно подключать геймпады Master System. В этом случае необходимо использовать схему с подтяжкой к 3,3В.
Питание для самого геймпада не требуется.

Схему подключения смотрите в "schematics/DE2-115 Master System gamepads adapter.pdf".

Назначение контактов GPIO для геймпадов первого и второго игрока:

* JP5 pin 15, JP5 pin 19, JP5 pin 23, JP5 pin 27, JP5 pin 33, JP5 pin 37 - SMS gamepad 1 (21UDLR, инвертированная логика)
* JP5 pin  2, JP5 pin 4,  JP5 pin 6,  JP5 pin 8,  JP5 pin 10, JP5 pin 14 - SMS gamepad 2 (21UDLR, инвертированная логика)

Назначение контактов на разъеме геймпада Master System:

pin 9 - кнопка 2, pin 6 - кнопка 1, pin 1 - вверх (Up), pin 2 - вниз (Down), pin 3 - влево (Left), pin 4 - вправо (Right), pin 8 - земля

Кнопка 1 на SMS геймпаде используется как кнопка B геймпада Mega Drive/Genesis.
Кнопка 2 на SMS геймпаде используется как кнопка C геймпада Mega Drive/Genesis.


## Содержимое проекта


Имя файла или директории                                | Описание файла или директории
--------------------------------------------------------|----------------------------------------------------------------------------
de2115_board                                            | Директория содержит модули специфичные для DE2-115
output_files/DE2_115_Genesis.sof                        | Файл конфигурации ПЛИС для загрузки по JTAG
rtl                                                     | Модули ядра Mega Drive/Genesis
schematics                                              | Cхемы подключения геймпадов Mega Drive и Master System
simulation/testbench                                    | Testbench для отдельных модулей проекта, для старта симуляции откройте "*.do" скрипт в Altera ModelSim
sys                                                     | Модули MiSTER фреймворка (top-level модуль проекта находится здесь)
DE2_115_Genesis.qpf                                     | Главный файл Quartus проекта
DE2_115_Genesis.qsf                                     | Файл с параметрами проекта Quartus
Genesis.sdc                                             | Список временных ограничений для ядра Mega Drive/Genesis
Genesis.sv                                              | Главный модуль ядра Mega Drive/Genesis
LICENSE                                                 | Лицензия GPL-3.0
README.md                                               | Англоязычная версия readme 
README_RUS.md                                           | Файл, который вы сейчас читаете
files.qip                                               | Quartus IP файл со списком файлов модулей ядра Mega Drive/Genesis и DE2-115


## Известные проблемы

* Virtual Racing не работает.
* Содержимое Save RAM не сохраняется после выключения питания.
