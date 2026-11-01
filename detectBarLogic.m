function [realBarHeight, foundBar] = detectBarLogic(imgInput)
% DETECTBARLOGIC מזהה את גובה המוט (מתח) בתמונה על בסיס גיאומטריה וקשרים לוגיים.
%   הפונקציה מבצעת עיבוד תמונה למציאת קווים אופקיים בחלק העליון של התמונה,
%   ומסננת אותם כדי למצוא את המוט האמיתי על ידי זיהוי המרווחים שיוצרות
%   ידי המשתמש האוחזות במוט.
%
%   INPUT:
%       imgInput - תמונת המקור (RGB או Grayscale).
%
%   OUTPUTS:
%       realBarHeight - גובה המוט בפיקסלים (ביחס לרזולוציה המקורית).
%       foundBar      - דגל בוליאני המציין האם המוט נמצא בהצלחה.

    % אתחול משתני פלט
    realBarHeight = [];
    foundBar = false;

    % ====================================================================
    % 1. עיבוד מקדים ונרמול רזולוציה (Preprocessing & Normalization)
    % ====================================================================
    % המרה לגווני אפור במידת הצורך
    if size(imgInput, 3) == 3
        grayImg = rgb2gray(imgInput);
    else
        grayImg = imgInput;
    end
    
    % שמירת הגודל המקורי לצורך המרה חזרה בסוף התהליך
    origWidth = size(grayImg, 2);
    
    % הקטנה לרזולוציית עבודה קבועה (רוחב 1000 פיקסלים)
    % שלב זה קריטי כדי להבטיח שהפרמטרים (כגון גודל הפער בין הידיים)
    % יעבדו בצורה אחידה גם בוידאו 4K וגם ב-480p.
    workingWidth = 1000;
    scaleFactor = workingWidth / origWidth;
    
    if scaleFactor < 1
        workImg = imresize(grayImg, scaleFactor);
    else
        workImg = grayImg;
        scaleFactor = 1; % לא מבצעים הגדלה מלאכותית
    end

    % ====================================================================
    % 2. גילוי שפות והגדרת אזור עניין (Edge Detection & ROI)
    % ====================================================================
    % שימוש באלגוריתם Canny לגילוי שפות חזק
    edges = edge(workImg, 'canny', [0.1 0.2]); 
    [rows, cols] = size(edges);
    
    % חיתוך ROI: התמקדות ב-40% העליונים של התמונה בלבד
    % (הנחה: מוט המתח תמיד נמצא בחלק העליון)
    roiHeight = round(rows * 0.4); 
    edges(roiHeight:end, :) = 0; 

    % ====================================================================
    % 3. התמרת הוף למציאת קווים (Hough Transform)
    % ====================================================================
    [H, T, R] = hough(edges);
    
    % מציאת השיאים (Peaks) במרחב הוף
    P = houghpeaks(H, 50, 'threshold', ceil(0.2*max(H(:))));
    
    % חילוץ הקווים (Line Segments)
    % FillGap: מאחד קטעי קו קרובים (מתגבר על הסתרות קטנות)
    % MinLength: מסנן רעשים קצרים
    lines = houghlines(edges, T, R, P, 'FillGap', 20, 'MinLength', 40);

    % ====================================================================
    % 4. סינון גיאומטרי: קווים אופקיים בלבד
    % ====================================================================
    lineData = [];
    for k = 1:length(lines)
        xy = [lines(k).point1; lines(k).point2];
        
        % חישוב זווית הקו
        angle = atan2d(xy(2,2) - xy(1,2), xy(2,1) - xy(1,1));
        
        % סינון: שמירה רק של קווים אופקיים (בטווח +-10 מעלות)
        if abs(angle) < 10 || abs(abs(angle)-180) < 10
            x_start = min(xy(:,1));
            x_end = max(xy(:,1));
            y_avg = mean(xy(:,2));
            lineData = [lineData; x_start, x_end, y_avg]; 
        end
    end

    if isempty(lineData), return; end

    % מיון הקווים לפי גובה (מלמעלה למטה)
    [~, sortIdx] = sort(lineData(:,3)); 
    sortedLines = lineData(sortIdx, :);
    
    % ====================================================================
    % 5. לוגיקה לזיהוי המוט: חיפוש מקבצים ומרווחים (Hand Gaps)
    % ====================================================================
    
    pixelToleranceY = 15; % טולרנס לאיחוד קווים באותו גובה
    minSegments = 3;      % דרישה ללפחות 3 מקטעים (למשל: שמאל--יד--אמצע--יד--ימין)
    
    % הגדרת רווח מינימלי לידיים באופן יחסי לרוחב התמונה (10%)
    minGapSize = cols * 0.1; 
    
    processedIndices = [];

    for i = 1:size(sortedLines, 1)
        if ismember(i, processedIndices), continue; end
        
        currentY = sortedLines(i, 3);
        
        % א. קיבוץ קווים הנמצאים בערך באותו גובה
        groupMask = abs(sortedLines(:, 3) - currentY) < pixelToleranceY;
        groupIndices = find(groupMask);
        groupData = sortedLines(groupIndices, :);
        processedIndices = [processedIndices; groupIndices];
        
        % סינון ראשוני: אם אין מספיק מקטעים, זה כנראה לא המוט
        if size(groupData, 1) < minSegments, continue; end
        
        % מיון הקבוצה משמאל לימין (לפי ציר X)
        [~, xSort] = sort(groupData(:, 1));
        sortedGroup = groupData(xSort, :);
        
        % ב. בדיקת קיום מרווחים (Gaps) המייצגים את הידיים
        validGapsFound = 0;
        for j = 1:(size(sortedGroup, 1) - 1)
            % חישוב המרחק בין סוף המקטע הנוכחי לתחילת המקטע הבא
            gap = sortedGroup(j+1, 1) - sortedGroup(j, 2);
            
            if gap > minGapSize
                validGapsFound = validGapsFound + 1;
            end
        end
        
        % ג. קבלת החלטה
        if validGapsFound >= 1 
            foundBar = true;
            
            % חישוב גובה המוט הממוצע (בתמונה המוקטנת)
            detectedHeightSmall = mean(sortedGroup(:, 3));
            
            % המרה חזרה לקואורדינטות התמונה המקורית
            realBarHeight = detectedHeightSmall / scaleFactor;
            
            break; % נמצא המוט הטוב ביותר, יציאה מהלולאה
        end
    end
end