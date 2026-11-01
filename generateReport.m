function generateReport(repsData, scores, heights, barY, thresh, weightVal)
% GENERATEREPORT מפיק דוח אימון גרפי (GUI) עם ניתוח ביצועים ומתן ציונים.
%   הפונקציה יוצרת חלון המציג גרפים של עוצמת התנועה וגובה הסנטר,
%   מחשבת ציון משוקלל לכל חזרה (על בסיס גובה ומהירות), ומציגה טבלה מסכמת
%   עם המלצה להמשך האימון (העלאת/הורדת משקל).
%
%   INPUTS:
%       repsData  - מטריצה המכילה את נתוני החזרות שזוהו:
%                   [duration, peakHeight, distFromBar, startFrame, endFrame]
%       scores    - וקטור ציוני תנועה (Motion Scores) לכל פריימים.
%       heights   - וקטור גובה המעקב (Y-position) לכל פריימים.
%       barY      - קואורדינטת ה-Y של המוט (קו הייחוס).
%       thresh    - סף הרעש ששימש לזיהוי תנועה.
%       weightVal - משקל העבודה של המשתמש (ק"ג) לתצוגה בדוח.

    % ====================================================================
    % 1. הגדרת קבועים ופרמטרים לחישוב הציון (Scoring Constants)
    % ====================================================================
    
    % פרמטרים לציון גובה (מרחק מעל המוט בפיקסלים)
    MIN_DIST_PX = 10;      % סף תחתון: פחות מזה יקבל ציון 0 ברכיב הגובה
    TARGET_DIST_PX = 100;  % יעד: מרחק זה ומעלה יקבל ציון 100 ברכיב הגובה
    
    % פרמטרים לציון זמן (בשניות)
    TARGET_TIME_SEC = 1.5; % זמן ביצוע מצוין (מהיר) - יקבל ציון 100
    MAX_TIME_SEC = 3.0;    % זמן ביצוע איטי מדי - יקבל ציון 0
    
    % ====================================================================
    % 2. יצירת חלון הדוח והגרפים (Visualization)
    % ====================================================================
    
    % יצירת החלון הראשי (Figure)
    fRes = figure('Name', 'Workout Report', ...
                  'NumberTitle', 'off', ...
                  'Position', [100, 100, 1200, 700]);
    
    % --- גרף עליון: עוצמת תנועה (Motion Intensity) ---
    subplot(2, 3, [1, 2]); 
    plot(scores, 'LineWidth', 1); hold on;
    yline(thresh, 'r--', 'Threshold'); % סימון סף הרעש
    title('Motion Intensity'); 
    grid on; 
    xlim([1 length(scores)]);
    
    % סימון החזרות שזוהו בתוך הגרף (מלבנים ירוקים)
    if ~isempty(repsData)
        yl = ylim;
        for i = 1:size(repsData, 1)
            startF = repsData(i,4);
            endF   = repsData(i,5);
            fill([startF endF endF startF], ...
                 [yl(1) yl(1) yl(2) yl(2)], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        end
    end
    
    % --- גרף תחתון: ניתוח גובה (Chin Height Analysis) ---
    subplot(2, 3, [4, 5]); 
    plot(heights, 'Color', [0.6 0.6 0.6]); hold on; % גובה גולמי באפור
    yline(barY, 'r-', 'Bar Limit', 'LineWidth', 2); % קו המוט
    set(gca, 'YDir', 'reverse'); % הפיכת ציר Y (ברוב התמונות 0 הוא למעלה)
    title('Chin Height Analysis'); 
    grid on; 
    xlim([1 length(heights)]);
    
    % הדגשת מהלך החזרה ושיא הגובה
    if ~isempty(repsData)
        for i = 1:size(repsData, 1)
            h = repsData(i, 2); % שיא הגובה
            s = repsData(i, 4); % פריים התחלה
            e = repsData(i, 5); % פריים סיום
            
            % ציור קו אופקי שמראה את שיא הגובה בחזרה זו
            plot([s, e], [h, h], 'b-', 'LineWidth', 2);
            % סימון נקודת השיא בעיגול אדום
            plot((s+e)/2, h, 'ro', 'MarkerFaceColor', 'r');
        end
    end
    
    % ====================================================================
    % 3. אלגוריתם חישוב ציונים וניתוח סטטיסטי
    % ====================================================================
    
    tableCellData = {};
    avgScore = 0;
    summaryTxt = '';
    recommendation = '';
    recColor = 'k'; % צבע ברירת מחדל לטקסט ההמלצה
    
    if ~isempty(repsData)
        numReps = size(repsData, 1);
        totalScoreSum = 0;
        
        for i = 1:numReps
            duration = repsData(i, 1);
            dist = repsData(i, 3);
            
            % --- שלב א': חישוב ציון גובה (משקל של 80% בציון הסופי) ---
            % נרמול המרחק לסקאלה של 0-100 באופן ליניארי
            hScore = (dist - MIN_DIST_PX) / (TARGET_DIST_PX - MIN_DIST_PX) * 100;
            hScore = min(100, max(0, hScore)); % ווידוא שהציון נשאר בטווח הגיוני
            
            % --- שלב ב': חישוב ציון זמן (משקל של 20% בציון הסופי) ---
            % ככל שהזמן קצר יותר (קרוב ליעד), הציון גבוה יותר
            if duration <= TARGET_TIME_SEC
                tScore = 100;
            elseif duration >= MAX_TIME_SEC
                tScore = 0;
            else
                % אינטרפולציה לינארית הפוכה לחישוב הציון
                tScore = 100 * (MAX_TIME_SEC - duration) / (MAX_TIME_SEC - TARGET_TIME_SEC);
            end
            
            % --- שלב ג': שקלול סופי ---
            finalRepScore = (0.8 * hScore) + (0.2 * tScore);
            totalScoreSum = totalScoreSum + finalRepScore;
            
            % קביעת ציון מילולי (Verbal Grade)
            if finalRepScore >= 85
                verbalGrade = 'מצוין';
            elseif finalRepScore >= 55
                verbalGrade = 'עובר';
            else
                verbalGrade = 'לא עובר';
            end
            
            % שמירת הנתונים לשורה בטבלה
            tableCellData(i, :) = {i, round(dist), sprintf('%.2fs', duration), ...
                                   round(finalRepScore), verbalGrade};
        end
        
        % --- סיכום והמלצות ---
        avgScore = totalScoreSum / numReps;
        
        % לוגיקה לקביעת המלצה על בסיס ממוצע הביצועים
        if avgScore >= 85
            recommendation = 'אפשר להעלות עומסים (קל מדי)';
            recColor = 'g'; % ירוק
        elseif avgScore >= 60
            recommendation = 'ציון עובר (משקל מתאים)';
            recColor = 'b'; % כחול
        else
            recommendation = 'כדאי להוריד עומסים (קשה/טכניקה לקויה)';
            recColor = 'r'; % אדום
        end
        
        summaryTxt = sprintf('Total Reps: %d\nAvg Score: %.1f\nWeight: %d kg', ...
            numReps, avgScore, weightVal);
            
    else
        % מקרה קצה: לא זוהו חזרות
        summaryTxt = 'No Reps Detected';
        recommendation = 'N/A';
        recColor = 'k';
    end
    
    % ====================================================================
    % 4. בניית פאנל הסיכום (UI Panel)
    % ====================================================================
    
    % יצירת פאנל בצד ימין
    hp = uipanel('Position', [0.68, 0.05, 0.30, 0.9], ...
                 'Title', 'Final Summary', 'FontSize', 12);
    
    % טקסט סיכום (מספר חזרות, ממוצע ומשקל)
    uicontrol('Parent', hp, 'Style', 'text', 'String', summaryTxt, ...
        'Units', 'normalized', 'Position', [0.05, 0.85, 0.9, 0.12], ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
        
    % טקסט המלצה (צבוע בהתאם לציון)
    uicontrol('Parent', hp, 'Style', 'text', 'String', recommendation, ...
        'Units', 'normalized', 'Position', [0.05, 0.78, 0.9, 0.08], ...
        'HorizontalAlignment', 'center', 'FontSize', 12, ...
        'ForegroundColor', recColor, 'FontWeight', 'bold');
    
    % הצגת הטבלה המפורטת
    uitable('Parent', hp, 'Data', tableCellData, ...
        'ColumnName', {'#', 'Dist (px)', 'Time', 'Score', 'Grade'}, ...
        'ColumnWidth', {30, 60, 60, 50, 80}, ...
        'Units', 'normalized', 'Position', [0.05, 0.05, 0.9, 0.7], ...
        'RowName', []);
        
end