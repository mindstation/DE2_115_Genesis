# Ядро [SEGA Megadrive/Genesis](https://en.wikipedia.org/wiki/Sega_Genesis) для платы Terasic DE2-115.

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
* SW[15] - включить/выключить порты геймпадов
* SW[5]  - joystick_0_B, SW[4] - joystick_0_C, SW[3] - joystick_0_Left, SW[2] - joystick_0_Up, SW[1] - joystick_0_Down, SW[0] - joystick_0_Right
* KEY[3] - joystick_0_START, KEY[2] - joystick_0_A
* SW[12] - joystick_1_B, SW[11] - joystick_1_C, SW[10] - joystick_1_Left, SW[9] - joystick_1_Up, SW[8] - joystick_1_Down, SW[7] - joystick_1_Right
* KEY[1] - joystick_1_START, KEY[0] - joystick_1_A


## Геймпады Mega Drive и Genesis

Включите SW[15] для использования геймпадов. Эмуляция геймпадов, посредством SW и KEY на плате, будет отключена.

К контактам GPIO на DE2-115 можно подключать 3 и 6 кнопочные геймпады Mega Drive и Genesis. А также любую другую периферию Mega Drive и Genesis.

Схему недорогого варианта подключения, с питанием 3,3В, смотрите в файле "schematics/DE2-115 Genesis and Mega Drive gamepads 3V3 adapter.pdf". Этот вариант подходит для аксессуаров работающих от 3,3В. Геймпады работают. Cхему не рекомендуется использовать для подключения Zero Tolerance Link Cable.

Для варианта с питанием 5В смотрите схему на базе модуля преобразователя логических уровней MiSTer SNAC - "schematics/DE2-115 Genesis and Mega Drive gamepads 5V SNAC adapter.pdf". Этот вариант, вероятно, совместим со всей периферией Mega Drive.

### GPIO, недорогое подключение 3,3В

Назначение контактов GPIO используемых для подключения геймпадов первого и второго игрока (питание 3,3В):

* JP5 pin 2, JP5 pin 4, JP5 pin 6, JP5 pin 8, JP5 pin 10, JP5 pin 12, JP5 pin 14, JP5 pin 16, JP5 pin 29 - gamepad 1 (C/Start, B/A, Right/Mode, Select, Left/X, GND, Down/Y, Up/Z, 3.3V)
* JP5 pin 26, JP5 pin 28, JP5 pin 30, JP5 pin 32, JP5 pin 34, JP5 pin 36, JP5 pin 38, JP5 pin 40, JP5 pin 29 - gamepad 2 (Up/Z, Down/Y, GND, Left/X, Select, Right/Mode, B/A, C/Start, 3.3V)

Назначение контактов на разъеме геймпада Mega Drive/Genesis (питание 3,3В):

pin 1 - Up/Z, pin 2 - Down/Y, pin 3 - Left/X, pin 4 - Right/Mode, pin 5 - 3.3V, pin 6 - B/A, pin 7 - "Select" сигнал выбора набора кнопок геймпада, pin 8 - GND, pin 9 - C/Start

Нумерация контактов в разъеме справа налево, по рядам. Первый справа контакт в верхнем ряду - pin 1. Последний - pin 5. Первый справа контакт в нижнем ряду - pin 6. Последний - pin 9.

Большинство геймпадов Mega Drive и Genesis прекрасно работают с трехвольтовым питанием. Если ваш геймпад не работает от 3,3В,
попробуйте схему на базе модуля преобразователя логических уровней MiSTer SNAC.

### GPIO, подключение посредством MiSTer SNAC

Назначение контактов GPIO используемых для подключения MiSTer SNAC первого и второго игрока:

* JP5 pin 2, JP5 pin 4, JP5 pin 6, JP5 pin 8, JP5 pin 10, JP5 pin 12, JP5 pin 14, JP5 pin 16, JP5 pin 11 - SNAC порт первого игрока (USB pin 9, USB pin 8, USB pin 7, USB pin 6, USB pin 5, USB pin 4 (GND), USB pin 3, USB pin 2, USB pin 1 (5В))
* JP5 pin 11, JP5 pin 26, JP5 pin 28, JP5 pin 30, JP5 pin 32, JP5 pin 34, JP5 pin 36, JP5 pin 38, JP5 pin 40 - SNAC порт второго игрока (USB pin 1 (5В), USB pin 2, USB pin 3, USB pin 4 (GND), USB pin 5, USB pin 6, USB pin 7, USB pin 8, USB pin 9)

Для подключения MiSTer SNAC можно воспользоваться модулем с USB 3.0 разъемом. Пример такого модуля представлен на фотографии ниже.

![USB 3.0 module](schematics/USB-CONN-3F-MODULE-FOR-SNAC.jpeg)


## Содержимое проекта


Имя файла или директории                                | Описание файла или директории
--------------------------------------------------------|----------------------------------------------------------------------------
de2115_board                                            | Директория содержит модули специфичные для DE2-115
output_files/DE2_115_Genesis.sof                        | Файл конфигурации ПЛИС для загрузки по JTAG
output_files/DE2_115_Genesis.jic                        | Файл конфигурации ПЛИС для загрузки в конфигурационную ПЗУ
rtl                                                     | Модули ядра Mega Drive/Genesis
schematics                                              | Cхемы подключения портов геймпадов Mega Drive/Genesis
simulation/testbench                                    | Testbench для отдельных модулей проекта, для старта симуляции откройте "*.do" скрипт в Altera ModelSim
sys                                                     | Модули MiSTer фреймворка (top-level модуль проекта находится здесь)
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
