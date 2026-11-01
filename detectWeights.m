function [count, isSuccess] = detectWeights(inputImage)
% DETECTWEIGHTS מזהה ומחשב את עומס המשקולות בתמונה באופן חצי-אוטומטי.
%   הפונקציה מציגה את התמונה למשתמש ומבקשת ממנו לסמן אזור עניין (ROI)
%   סביב צלחות המשקל. לאחר מכן, היא מבצעת עיבוד תמונה כדי להפריד את
%   הצלחות מהרקע, סופרת אותן באמצעות אלגוריתם סריקת שורה (Scanline),
%   ומחזירה את המשקל הכולל בק"ג.
%
%   INPUT:
%       inputImage - תמונת המקור (RGB) המכילה את המוט והמשקולות.
%
%   OUTPUTS:
%       count     - המשקל הכולל שחושב (בק"ג).
%       isSuccess - דגל בוליאני (true/false) המציין אם הזיהוי הצליח.

    % אתחול משתנים
    count = 0;
    isSuccess = false;
    
    % בדיקת תקינות קלט בסיסית
    if isempty(inputImage)
        return;
    end
    
    % ====================================================================
    % 1. אינטראקציה עם המשתמש: בחירת אזור עניין (ROI)
    % ====================================================================
    
    % יצירת חלון זמני לבחירה
    f_temp = figure('Name', 'Select Weights', 'NumberTitle', 'off', 'MenuBar', 'none');
    imshow(inputImage);
    title('Draw a rectangle around the weights (middle height)', 'FontSize', 14);
    
    % ביצוע החיתוך (imcrop עוצר את הריצה עד שהמשתמש מסמן ולוחץ פעמיים)
    [I_roi, rect] = imcrop(f_temp);
    
    % סגירת החלון בצורה בטוחה
    if isvalid(f_temp)
        close(f_temp);
    end
    
    % בדיקה אם המשתמש ביטל את הבחירה (למשל סגר את החלון ללא סימון)
    if isempty(I_roi)
        return;
    end
    
    % ====================================================================
    % 2. עיבוד תמונה (Image Processing Pipeline)
    % ====================================================================
    
    % שלב א': המרה לגווני אפור ושיפור ניגודיות
    % אנו משתמשים ב-CLAHE (Contrast Limited Adaptive Histogram Equalization)
    % כדי להדגיש את ההבדלים בין הצלחות לרקע גם בתנאי תאורה קשים.
    gray_roi = rgb2gray(I_roi);
    gray_enhanced = adapthisteq(gray_roi, 'ClipLimit', 0.03, 'Distribution', 'rayleigh');
    
    % שלב ב': בינאריזציה (Binarization)
    % הופכים את הצבעים (imcomplement) כי בדרך כלל הצלחות כהות והרקע בהיר,
    % ואנו רוצים שהאובייקטים למדידה יהיו "לבנים" (1).
    gray_inv = imcomplement(gray_enhanced);
    
    % שימוש בסף (Threshold) קבוע של 0.65 להפרדת הצלחות
    bw = imbinarize(gray_inv, 0.65); 
    
    % ====================================================================
    % 3. אלגוריתם ספירה (Scanline Analysis)
    % ====================================================================
    
    % חילוץ שורת פיקסלים בודדת ממרכז האזור המסומן
    [rows, ~] = size(bw);
    mid_row = round(rows / 2);
    scanline_data = bw(mid_row, :);
    
    % ספירת רכיבים קשירים (Connected Components) לאורך השורה
    % bwlabel מחזיר את מספר האובייקטים המופרדים (num_lines)
    [~, num_lines] = bwlabel(scanline_data);
    
    % ====================================================================
    % 4. חישוב המשקל הסופי
    % ====================================================================
    
    % הנחה: כל צלחת מזוהה כקבוצת פיקסלים לבנים.
    % אנו מפחיתים 1 מהספירה (לנטרול זיהוי שגוי של קצה המוט/סוגר)
    % ומכפילים ב-20 ק"ג (משקל סטנדרטי לצלחת גדולה).
    plateCount = max(0, num_lines - 1);
    count = plateCount * 20;
    
    % עדכון סטטוס הצלחה
    isSuccess = true;

end