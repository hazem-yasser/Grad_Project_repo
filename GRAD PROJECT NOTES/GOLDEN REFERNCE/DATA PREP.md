هذا الكود هو "مترجم" البيانات. الشبكة العصبية (Neural Network) لا تفهم معنى "موجة" أو "أرقام مركبة" (Complex Numbers) بشكل مباشر، لذا وظيفة هذا الكود تحويل إشارات الاتصالات إلى "أرقام ومصفوفات" يستطيع الذكاء الاصطناعي فهمها والتعلم منها.

إليك شرح الكود سطراً بسطر مع توضيح "ليه عملنا كده؟":

### 1. تجهيز "الشباك" (Sliding Window Strategy)

الفكرة الأساسية هنا: عشان الشبكة تصلح الرمز رقم 10، مينفعش تبص عليه لوحده. لازم تبص على الرموز اللي قبله (8 و 9) واللي بعده (11 و 12) عشان تفهم تأثير التداخل (ISI). ده بنسميه "السياق" أو **Context**.

#### **الكود بالتفصيل:**

- **`pad_width = window_size // 2`**:
    
    - **ليه؟** عشان لما نيجي عند أول رمز خالص (رقم 0)، مفيش قبله حاجة. فبنحط "أصفار" (Padding) في البداية والنهاية عشان الشباك يلاقي حاجة ياخدها وما يحصلش خطأ (Error).
        
- **`window = rx_padded[i : i + window_size]`**:
    
    - هنا بنقطع "شريحة" من الإشارة. لو الـ Window Size = 5، الشريحة دي هيكون فيها الرمز الحالي + 2 قبله + 2 بعده.
        

### 2. فك الاشتباك (Flattening Complex Numbers)

الشبكات العصبية التقليدية (MLP) بتتعامل مع أرقام حقيقية (Real Numbers) بس. مفيش "سلك" بيدخل فيه رقم مركب ($3 + 4j$).

- **`features = np.concatenate([window.real, window.imag])`**:
    
    - **الحركة الذكية:** احنا بنفصل الجزء الحقيقي (Real) عن التخيلي (Imaginary).
        
    - لو الشباك فيه 5 أرقام مركبة، احنا بنحولهم لـ **10 أرقام حقيقية**.
        
    - **الترتيب:** بنرص الـ 5 Real الأول، وبعدين الـ 5 Imaginary.
        
    - **النتيجة:** الـ Input Layer في الشبكة هيكون ليها 10 مداخل (Neurons).
        

### 3. تحديد الهدف (The Target)

- **`target = [tx_signal[i].real, tx_signal[i].imag]`**:
    
    - ده "الإجابة النموذجية". احنا بنقول للشبكة: "لما تشوفي الشباك المشوه ده (X)، المفروض تطلعي الرمز النضيف ده (y)".
        
    - طبعاً بناخد الرمز الأصلي (Clean TX) مش المستقبل (RX).
        

### 4. التقسيم (Train/Test Split)

- **`train_test_split(..., test_size=0.2)`**:
    
    - بنقسم الداتا لجزئين:
        
        1. **Training (80%):** دي الداتا اللي الشبكة "هتذاكر" منها وتعدل الـ Weights بتاعتها.
            
        2. **Testing (20%):** دي "الامتحان". داتا الشبكة عمرها ما شافتها قبل كده، بنستخدمها عشان نقيس شطارتها في الآخر.
            

---

### **ملخص العملية (Visual Summary):**

تخيل إن عندك شريط فيديو بايظ (الإشارة المستقبلة).

1. **Padding:** بتلزق شريط فاضي في الأول وفي الآخر.
    
2. **Windowing:** بتمسك "مقص" وتقص كل 5 لقطات مع بعض وتحطهم في ظرف.
    
3. **Flattening:** بتاخد كل لقطة، تفصل الصورة (Real) عن الصوت (Imag)، وترتبهم جنب بعض.
    
4. **Target:** بتجيب النسخة الأصلية من الفيلم (TX Signal) وتحط اللقطة النضيفة المقابلة كـ "حل" للظرف ده.
    

الآن الداتا جاهزة تماماً للدخول لـ "مصنع" الذكاء الاصطناعي (Block 2). هل الأشكال (Shapes) اللي طلعتلك منطقية؟ `(Samples, 10)` و `(Samples, 2)`؟

```python
# =============================================================================
# BLOCK 1: DATA PREPARATION (Sliding Window & Feature Engineering)
# =============================================================================
from sklearn.model_selection import train_test_split
import tensorflow as tf # Import tensorflow here for later blocks

def prepare_data(rx_signal, tx_signal, window_size=5):
    X = []
    y = []
    
    # Pad the signal so we don't lose the first few symbols
    pad_width = window_size // 2
    rx_padded = np.pad(rx_signal, (pad_width, pad_width), mode='constant')
    
    for i in range(len(rx_signal)):
        # 1. Grab the window (Context)
        # e.g., if i=10, window is from 8 to 12 (centered on 10)
        window = rx_padded[i : i + window_size]
        
        # 2. Separate Real and Imaginary parts (The "Flattening")
        # Input Vector: [Re(t-2), ..., Re(t), ..., Re(t+2), Im(t-2),.., Im(t),..,Im(t+2)]
        features = np.concatenate([window.real, window.imag])
        X.append(features)
        
        # 3. Grab the Target (The clean center symbol)
        target = [tx_signal[i].real, tx_signal[i].imag]
        y.append(target)
        
    return np.array(X), np.array(y)

# --- Configuration ---
WINDOW_SIZE = 5  # Context window

# Run the function using your NEW variables (rx_final)
print("Preparing Dataset...")
X_data, y_data = prepare_data(rx_final, tx_symbols, WINDOW_SIZE)

# Split into Training (80%) and Testing (20%)
X_train, X_test, y_train, y_test = train_test_split(X_data, y_data, test_size=0.2, random_state=42)

print(f"Data Ready!")
print(f"Input Shape: {X_train.shape} (Samples, Features)")
print(f"Target Shape: {y_train.shape} (Samples, Real/Imag)")
```